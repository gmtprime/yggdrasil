defmodule Yggdrasil.Distributor.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil distributor adapter for RabbitMQ.

  The name of a channel is a tuple with the exchange name and the routing key
  respectively.
  """
  use Connection

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend

  defstruct [:publisher, :channel, :routing_key, :exchange, :conn, :chan]
  alias __MODULE__, as: State

  #############################################################################
  # Client API.

  @doc """
  Starts a RabbitMQ distributor adapter in a `channel` with some distributor
  `publisher` and optionally `GenServer` `options`.
  """
  def start_link(%Channel{} = channel, publisher, options \\ []) do
    state = %State{publisher: publisher, channel: channel}
    Connection.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops the RabbitMQ adapter with its `pid`.
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  #############################################################################
  # Connection callbacks.

  @doc false
  def init(%State{channel: %Channel{name: {_, _}}} = state) do
    Process.flag(:trap_exit, true)
    {:connect, :init, state}
  end

  @doc false
  def connect(
    _info,
    %State{channel: %Channel{name: {exchange, routing_key}} = channel} = state
  ) do
    options = rabbitmq_options(channel)
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
    %State{channel: %Channel{name: {exchange, routing_key}}} = state
  ) do
    metadata = [channel: {exchange, routing_key}, error: error]
    Logger.error("Cannot connect to RabbitMQ #{inspect metadata}")
    {:backoff, 5000, state}
  end

  ##
  # Connected.
  defp connected(
    conn,
    chan,
    %State{channel: %Channel{name: {exchange, routing_key}}} = state
  ) do
    Process.monitor(conn.pid)
    metadata = [channel: {exchange, routing_key}]
    Logger.debug("Connected to RabbitMQ #{inspect metadata}")
    new_state = %State{state | conn: conn, chan: chan}
    {:ok, new_state}
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
    %State{channel: %Channel{name: {exchange, routing_key}}} = state
  ) do
    metadata = [channel: {exchange, routing_key}]
    Logger.debug("Disconnected from RabbitMQ #{inspect metadata}")
    {:backoff, 5000, state}
  end

  @doc false
  def handle_info(
    {:basic_consume_ok, _},
    %State{channel: %Channel{} = channel} = state
  ) do
    Backend.connected(channel)
    {:noreply, state}
  end
  def handle_info(
    {:basic_deliver, message, info},
    %State{
      publisher: publisher,
      chan: chan
    } = state
  ) do
    %{delivery_tag: tag,
      redelivered: redelivered,
      exchange: exchange,
      routing_key: routing_key
     } = info
    try do
      :ok = AMQP.Basic.ack(chan, tag)
      Publisher.notify(publisher, {exchange, routing_key}, message)
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
    %State{channel: %Channel{name: {exchange, routing_key}}}
  ) do
    metadata = [channel: {exchange, routing_key}, error: reason]
    Logger.debug("Terminated RabbitMQ connection #{inspect metadata}")
    :ok
  end

  #############################################################################
  # Helpers.

  @doc false
  def rabbitmq_options(%Channel{namespace: Yggdrasil}) do
    Application.get_env(:yggdrasil, :rabbitmq, [])
  end
  def rabbitmq_options(%Channel{namespace: namespace}) do
    default = [rabbitmq: []]
    result = Application.get_env(:yggdrasil, namespace, default)
    Keyword.get(result, :rabbitmq, [])
  end
end
