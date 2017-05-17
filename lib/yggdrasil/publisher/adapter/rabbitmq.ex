defmodule Yggdrasil.Publisher.Adapter.RabbitMQ do
  @moduledoc """
  A server for Redis publishing.

  The name of a channel is a tuple containing the exchange name and the routing
  key respectively.
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
    Logger.error("Cannot connect to RabbitMQ #{inspect metadata}")
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
    Logger.debug("Disconnected from RabbitMQ")
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
    Logger.debug("Terminated RabbitMQ connection #{inspect metadata}")
    :ok
  end
end
