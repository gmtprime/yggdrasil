defmodule Yggdrasil.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil adapter for RabbitMQ.
  """
  use Connection
  use Yggdrasil.Adapter, module: Connection

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
        AMQP.Queue.bind(chan, queue, exchange, routing_key: routing_key)
        {:ok, _consumer_tag} = AMQP.Basic.consume(chan, queue)
        new_state = %State{state | conn: conn, chan: chan}
        {:ok, new_state}
      {:error, _} ->
        {:backoff, 1000, state}
    end
  end

  @doc false
  def disconnect(_info, %State{conn: conn} = state) do
    AMQP.Connection.close(conn)
    new_state = %State{state | chan: nil, conn: nil}
    {:connect, :reconnect, new_state}
  end

  @doc false
  def handle_info({:basic_consume_ok, _}, %State{} = state) do
    {:noreply, state}
  end
  def handle_info(
    {:basic_deliver, message, %{consumer_tag: tag, redelivered: redelivered}},
    %State{publisher: publisher, routing_key: channel, chan: chan} = state
  ) do
    try do
      AMQP.Basic.ack(chan, tag)
      Publisher.sync_notify(publisher, channel, message)
      {:noreply, state}
    rescue
      _ ->
        AMQP.Basic.reject(chan, tag, requeue: not redelivered)
    end
  end
  def handle_info({:basic_cancel, _}, %State{} = state) do
    {:disconnect, :cancel, :cancel, state}
  end
  def handle_info({:DOWN, _, :process, _pid, _reason}, %State{} = state) do
    {:disconnect, :down, :down, state}
  end
  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(_reason, %State{conn: conn}) do
    AMQP.Connection.close(conn)
    :ok
  end
end
