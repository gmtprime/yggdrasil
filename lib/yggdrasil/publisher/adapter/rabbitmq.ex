defmodule Yggdrasil.Publisher.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil publisher adapter for RabbitMQ. The name of the channel should be
  a tuple with the name of the exchange and the routing key. The exchange
  should be a topic e.g:

  Subscription to channel:

  ```elixir
  iex(1)> alias Yggdrasil.Channel
  iex(2)> sub_channel = %Channel{
  ...(2)>   name: {"amq.topic", "r_key"},
  ...(2)>   adapter: Yggdrasil.Subscriber.Adapter.RabbitMQ
  ...(2)> }
  iex(3)> Yggdrasil.subscribe(sub_channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Channel{name: {"amq.topic", "r_key"}, (...)}}
  ```

  Publishing message:

  ```elixir
  iex(5)> pub_channel = %Channel{
  ...(5)>   name: {"amp.topic", "r_key"},
  ...(5)>   adapter: Yggdrasil.Publisher.Adapter.RabbitMQ
  ...(5)> }
  iex(6)> Yggdrasil.publish(pub_channel, "message")
  :ok
  ```

  Subscriber receiving message:

  ```elixir
  iex(7)> flush()
  {:Y_EVENT, %Channel{name: {"amq.topic", "r_key"}, (...)}, "message"}
  ```

  Instead of having `sub_channel` and `pub_channel`, the hibrid channel can be
  used. For the previous example we can do the following:

  ```elixir
  iex(1)> alias Yggdrasil.Channel
  iex(2)> channel = %Channel{name: {"amq.topic", "r_key"}, adapter: :rabbitmq}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Channel{name: {"amq.topic", "r_key"}, (...)}}
  iex(5)> Yggdrasil.publish(channel, "message")
  :ok
  iex(6)> flush()
  {:Y_EVENT, %Channel{name: {"amq.topic", "r_key"}, (...)}, "message"} 
  ```
  """
  use Connection

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection, as: Conn

  defstruct [:conn, :chan, :namespace]
  alias __MODULE__, as: State

  #############################################################################
  # Client API.

  @doc """
  Starts a RabbitMQ publisher with a `namespace`. Additianally you can add
  `GenServer` `options`.
  """
  def start_link(namespace, options \\ []) do
    Connection.start_link(__MODULE__, namespace, options)
  end

  @doc """
  Stops a RabbitMQ `publisher`.
  """
  def stop(publisher) do
    GenServer.stop(publisher)
  end

  @doc """
  Publishes a `message` in a `channel` using a `publisher`.
  """
  def publish(publisher, %Channel{} = channel, message) do
    Connection.call(publisher, {:publish, channel, message})
  end

  #############################################################################
  # GenServer callback.

  @doc false
  def init(namespace) do
    Process.flag(:trap_exit, true)
    state = %State{namespace: namespace}
    {:connect, :init, state}
  end

  @doc false
  def connect(_info, %State{namespace: namespace} = state) do
    options = Conn.rabbitmq_options(namespace)
    {:ok, conn} = AMQP.Connection.open(options)
    try do
      AMQP.Channel.open(conn)
    catch
      _, reason ->
        backoff(reason, state)
    else
      {:ok, chan} ->
        connected(conn, chan, state)
      error ->
        backoff(error, state)
    end
  end

  defp backoff(error, %State{} = state) do
    metadata = [error: error]
    Logger.error(fn ->
      "Cannot connect to RabbitMQ #{inspect metadata}"
    end)
    {:backoff, 5000, state}
  end

  defp connected(conn, chan, %State{} = state) do
    Process.monitor(conn.pid)
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

  defp disconnected(%State{} = state) do
    Logger.debug(fn -> "Disconnected from RabbitMQ" end)
    {:backoff, 5000, state}
  end

  @doc false
  def handle_call({:publish, _, _}, _from, %State{chan: nil} = state) do
    {:reply, {:error, "Disconnected"}, state}
  end
  def handle_call(
    {:publish,
     %Channel{name: {exchange, routing_key}, transformer: encoder} = channel,
     message},
    _from,
    %State{chan: chan} = state
  ) do
    result =
      with {:ok, encoded} <- encoder.encode(channel, message),
           do: AMQP.Basic.publish(chan, exchange, routing_key, encoded)
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

  defp terminated(reason, %State{} = _state) do
    metadata = [error: reason]
    Logger.debug(fn ->
      "Terminated RabbitMQ connection #{inspect metadata}"
    end)
    :ok
  end
end
