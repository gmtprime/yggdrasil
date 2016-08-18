defmodule Yggdrasil.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil adapter for RabbitMQ.
  """
  use Connection
  use Yggdrasil.Adapter, module: Connection
  require Logger

  alias Yggdrasil.Adapter 
  alias Yggdrasil.Publisher

  ##
  # State for RabbitMQ adapter.
  defstruct [:publisher, :routing_key, :exchange, :conn, :chan, :parent]
  alias __MODULE__, as: State

  ##
  # Gets Redis options from configuration.
  defp rabbitmq_options do
    Application.get_env(:yggdrasil, :rabbitmq, [])
  end

  @doc false
  def is_connected?(adapter) do
    Connection.call(adapter, :connected?)
  end

  @doc false
  def init(%Adapter{publisher: publisher, channel: {exchange, channel}}) do
    Process.flag(:trap_exit, true)
    state = %State{publisher: publisher,
                   routing_key: channel,
                   exchange: exchange}
    {:connect, :init, state}
  end

  @doc false
  def connect(
    _info,
    %State{exchange: exchange, routing_key: routing_key} = state
  ) do
    options = rabbitmq_options()
    {:ok, conn} = AMQP.Connection.open(options)
    try do
      consume(conn, exchange, routing_key)
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

  ##
  # Starts consuming from an exchange.
  defp consume(conn, exchange, routing_key) do
    {:ok, chan} = AMQP.Channel.open(conn)
    {:ok, %{queue: queue}} = AMQP.Queue.declare(chan, "", exclusive: true)
    :ok = AMQP.Queue.bind(chan, queue, exchange, routing_key: routing_key)
    {:ok, _} = AMQP.Basic.consume(chan, queue)
    {:ok, chan}
  end

  ##
  # Backoff.
  defp backoff(
    error,
    %State{exchange: exchange, routing_key: routing_key, parent: nil} = state
  ) do
    metadata = [channel: {exchange, routing_key}, error: error]
    Logger.error("Cannot connect to RabbitMQ #{inspect metadata}")
    {:backoff, 5000, state}
  end
  defp backoff(error, %State{parent: pid} = state) do
    send pid, false
    backoff(error, %State{state | parent: nil})
  end

  ##
  # Connected.
  defp connected(
    conn,
    chan,
    %State{exchange: exchange, routing_key: routing_key, parent: nil} = state
  ) do
    Process.monitor(conn.pid)
    metadata = [channel: {exchange, routing_key}]
    Logger.debug("Connected to RabbitMQ #{inspect metadata}")
    new_state = %State{state | conn: conn, chan: chan}
    {:ok, new_state}
  end
  defp connected(conn, chan, %State{parent: pid} = state) do
    send pid, true
    connected(conn, chan, %State{state | parent: nil})
  end

  @doc false
  def disconnect(_info, %State{conn: nil} = state) do
    disconnected(state)
  end
  def disconnect(info, %State{conn: conn} = state) do
    AMQP.Connection.close(conn)
    disconnect(info, %State{state | conn: nil, chan: nil})
  end

  ##
  # Disconnected.
  defp disconnected(
    %State{exchange: exchange, routing_key: routing_key} = state
  ) do
    metadata = [channel: {exchange, routing_key}]
    Logger.debug("Disconnected from RabbitMQ #{inspect metadata}")
    {:backoff, 5000, state}
  end

  @doc false
  def handle_call(:connected?, from, %State{conn: nil} = state) do
    pid = spawn_link fn ->
      result = receive do
        result -> result
      after
        5000 -> false
      end
      Connection.reply(from, result)
    end
    {:noreply, %State{state | parent: pid}}
  end
  def handle_call(:connected?, _from, %State{} = state) do
    {:reply, true, state}
  end

  @doc false
  def handle_info({:basic_consume_ok, _}, %State{} = state) do
    {:noreply, state}
  end
  def handle_info(
    {:basic_deliver, message, info},
    %State{
      publisher: publisher,
      exchange: exchange,
      chan: chan
    } = state
  ) do
    %{delivery_tag: tag, redelivered: redelivered, routing_key: real} = info
    try do
      :ok = AMQP.Basic.ack(chan, tag)
      Publisher.sync_notify(publisher, {exchange, real}, message)
    rescue
      _ ->
        :ok = AMQP.Basic.reject(chan, tag, requeue: not redelivered)
    end
    {:noreply, state}
  end
  def handle_info({:basic_cancel, _}, %State{} = state) do
    {:disconnect, :cancel, state}
  end
  def handle_info({:DOWN, _, :process, _pid, _reason}, %State{} = state) do
    new_state = %State{state | conn: nil, chan: nil}
    {:disconnect, :down, new_state}
  end
  def handle_info({:EXIT, _, _}, %State{} = state) do
    new_state = %State{state | conn: nil, chan: nil}
    {:disconnect, :exit, new_state}
  end
  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(reason, %State{conn: nil} = state) do
    terminated(reason, state)
  end
  def terminate(reason, %State{conn: conn} = state) do
    AMQP.Connection.close(conn)
    terminate(reason, %State{state | conn: nil, chan: nil})
  end

  ##
  # Terminated.
  defp terminated(
    reason,
    %State{exchange: exchange, routing_key: routing_key}
  ) do
    metadata = [channel: {exchange, routing_key}, error: reason]
    Logger.debug("Terminated RabbitMQ connection #{inspect metadata}")
    :ok
  end
end
