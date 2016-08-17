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
  defstruct [:publisher, :routing_key, :exchange, :conn, :chan]
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
    case AMQP.Connection.open(options) do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = AMQP.Channel.open(conn)
        {:ok, %{queue: queue}} = AMQP.Queue.declare(chan, "", exclusive: true)
        :ok = AMQP.Queue.bind(chan, queue, exchange, routing_key: routing_key)
        {:ok, _consumer_tag} = AMQP.Basic.consume(chan, queue)
        new_state = %State{state | conn: conn, chan: chan}
        metadata = [channel: {exchange, routing_key}]
        Logger.debug("Connected to RabbitMQ #{inspect metadata}")
        {:ok, new_state}
      {:error, error} ->
        metadata = [channel: {exchange, routing_key}, error: error]
        Logger.error("Cannot connect to RabbitMQ #{inspect metadata}")
        {:backoff, 1000, state}
    end
  end

  @doc false
  def disconnect(
    _info,
    %State{conn: conn, exchange: exchange, routing_key: routing_key} = state
  ) do
    AMQP.Connection.close(conn)
    metadata = [channel: {exchange, routing_key}]
    Logger.debug("Disconnected from RabbitMQ #{inspect metadata}")
    new_state = %State{state | chan: nil, conn: nil}
    {:connect, :reconnect, new_state}
  end

  @doc false
  def handle_call(:connected?, _from, %State{conn: nil} = state) do
    {:reply, false, state}
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
    {:disconnect, :down, state}
  end
  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(
    _reason,
    %State{conn: nil, exchange: exchange, routing_key: routing_key}
  ) do
    metadata = [channel: {exchange, routing_key}]
    Logger.debug("Terminated RabbitMQ connection #{inspect metadata}")
    :ok
  end
  def terminate(reason, %State{conn: conn} = state) do
    AMQP.Connection.close(conn)
    terminate(reason, %State{state | conn: nil})
  end
end
