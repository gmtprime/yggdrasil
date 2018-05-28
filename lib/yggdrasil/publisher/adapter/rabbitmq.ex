defmodule Yggdrasil.Publisher.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil publisher adapter for RabbitMQ. The name of the channel should be
  a tuple with the name of the exchange and the routing key. The exchange
  should be a topic (or any exhange that redirect to topic) e.g:

  Subscription to channel:

  ```
  iex(1)> name = {"amq.topic", "channel"}
  iex(2)> channel = %Yggdrasil.Channel{name: name, adapter: :rabbitmq}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: {"amq.topic", "channel"}, (...)}}
  ```

  Publishing message:

  ```
  iex(5)> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  Subscriber receiving message:

  ```
  iex(6)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: {"amq.topic", "channel"}, (...)}, "foo"}
  ```

  The subscriber can also unsubscribe from the channel:

  ```
  iex(7)> Yggdrasil.unsubscribe(channel)
  :ok
  iex(8)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{name: {"amq.topic", "channel"}, (...)}}
  ```
  """
  use Connection

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection, as: Conn

  defstruct [:conn, :chan, :namespace]
  alias __MODULE__, as: State

  ############
  # Client API

  @doc """
  Starts a RabbitMQ publisher with a `namespace`. Additianally you can add
  `GenServer` `options`.
  """
  @spec start_link(term()) :: GenServer.on_start()
  @spec start_link(term(), GenServer.options()) :: GenServer.on_start()
  def start_link(namespace, options \\ [])

  def start_link(namespace, options) do
    Connection.start_link(__MODULE__, namespace, options)
  end

  @doc """
  Stops a RabbitMQ `publisher`.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(publisher)

  def stop(publisher) do
    GenServer.stop(publisher)
  end

  @doc """
  Publishes a `message` in a `channel` using a `publisher` and optional
  `options`. The `options` argument is a `Keyword` list of options expected
  by `AMQP.Basic.publish/5` in its fifth argument.
  """
  @spec publish(GenServer.server(), Channel.t(), term()) ::
    :ok | {:error, term()}
  @spec publish(GenServer.server(), Channel.t(), term(), Keyword.t()) ::
    :ok | {:error, term()}
  def publish(publisher, channel, message, options \\ [])

  def publish(publisher, %Channel{} = channel, message, options) do
    Connection.call(publisher, {:publish, channel, message, options})
  end

  ####################
  # GenServer callback

  @doc false
  def init(namespace) do
    Process.flag(:trap_exit, true)
    state = %State{namespace: namespace}
    Logger.debug(fn -> "Started #{__MODULE__} for #{namespace}" end)
    {:connect, :init, state}
  end

  @doc false
  def connect(_info, %State{namespace: namespace} = state) do
    options = Conn.rabbitmq_options(namespace)
    try do
      with {:ok, conn} <- AMQP.Connection.open(options),
           {:ok, chan} <- AMQP.Channel.open(conn) do
        connected(conn, chan, state)
      else
        error ->
          backoff(error, state)
      end
    catch
      _, reason ->
        backoff(reason, state)
    end
  end

  defp backoff(error, %State{namespace: namespace} = state) do
    Logger.warn(fn ->
      "#{__MODULE__} cannot connect to RabbitMQ for #{namespace}" <>
      "due to #{inspect error}"
    end)
    {:backoff, 5000, state}
  end

  defp connected(conn, chan, %State{namespace: namespace} = state) do
    Process.monitor(conn.pid)
    Logger.debug(fn ->
      "#{__MODULE__} connected to RabbitMQ for #{namespace}"
    end)
    {:ok, %State{state | conn: conn, chan: chan}}
  end

  @doc false
  def disconnect(_info, %State{conn: nil} = state) do
    disconnected(state)
  end
  def disconnect(info, %State{conn: conn} = state) do
    AMQP.Connection.close(conn)
    disconnect(info, %State{state | conn: nil, chan: nil})
  end

  defp disconnected(%State{namespace: namespace} = state) do
    Logger.warn(fn ->
      "#{__MODULE__} disconnected from RabbitMQ for #{namespace}"
    end)
    {:backoff, 5000, state}
  end

  @doc false
  def handle_call({:publish, _, _, _}, _from, %State{chan: nil} = state) do
    {:reply, {:error, "Disconnected"}, state}
  end
  def handle_call(
    {:publish,
     %Channel{name: {exchange, routing_key}, transformer: encoder} = channel,
     message,
     options},
    _from,
    %State{chan: chan} = state
  ) do
    result =
      with {:ok, encoded} <- encoder.encode(channel, message),
           do: AMQP.Basic.publish(chan, exchange, routing_key, encoded, options)
    {:reply, result, state}
  end
  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def handle_info({:DOWN, _, :process, _pid, _reason}, %State{} = state) do
    new_state = %State{state | conn: nil, chan: nil}
    {:disconnect, :down, new_state}
  end
  def handle_info({:EXIT, _, _}, %State{} = state) do
    new_state = %State{state | conn: nil, chan: nil}
    {:disconnect, :exit, new_state}
  end

  @doc false
  def terminate(reason, %State{conn: nil} = state) do
    terminated(reason, state)
  end
  def terminate(reason, %State{conn: conn} = state) do
    AMQP.Connection.close(conn)
    terminate(reason, %State{state | conn: nil, chan: nil})
  end

  defp terminated(:normal, %State{namespace: namespace} = _state) do
    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect namespace}"
    end)
  end
  defp terminated(reason, %State{namespace: namespace} = _state) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect namespace} due to #{inspect reason}"
    end)
  end
end
