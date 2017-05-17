defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ do
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
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator

  defstruct [:publisher, :channel, :chan]
  alias __MODULE__, as: State

  ############
  # Client API

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

  ######################
  # Connection callbacks

  @doc false
  def init(%State{channel: %Channel{name: {_, _}}} = state) do
    Process.flag(:trap_exit, true)
    {:connect, :init, state}
  end

  @doc false
  def connect(_, %State{channel: %Channel{namespace: namespace}} = state) do
    with {:ok, _} <- Generator.connect(namespace),
         {:ok, chan} <- Generator.open_channel(namespace) do
      try do
        connected(chan, state)
      catch
        _, reason ->
          backoff(reason, state)
      end
    else
      error ->
        backoff(error, state)
    end
  end

  @doc false
  def disconnect(_info, %State{chan: nil} = state) do
    disconnected(state)
  end
  def disconnect(info, %State{chan: _} = state) do
    disconnect(info, %State{state | chan: nil})
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
  def handle_info({:DOWN, _, _, pid, _}, %State{chan: %{pid: pid}} = state) do
    {:disconnect, :down, state}
  end
  def handle_info({:EXIT, _, pid}, %State{chan: %{pid: pid}} = state) do
    {:disconnect, :exit, state}
  end
  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(reason, %State{chan: nil} = state) do
    terminated(reason, state)
  end
  def terminate(reason, %State{chan: _} = state) do
    terminate(reason, %State{state | chan: nil})
  end

  #########
  # Helpers

  @doc false
  def rabbitmq_options(%Channel{namespace: Yggdrasil}) do
    Application.get_env(:yggdrasil, :rabbitmq, [])
  end
  def rabbitmq_options(%Channel{namespace: namespace}) do
    default = [rabbitmq: []]
    result = Application.get_env(:yggdrasil, namespace, default)
    Keyword.get(result, :rabbitmq, [])
  end

  @doc false
  def connected(
    chan,
    %State{channel: %Channel{name: {exchange, routing_key}}} = state
  ) do
    Process.monitor(chan.pid)
    {:ok, new_state} = consume(chan, state)
    metadata = [channel: {exchange, routing_key}]
    Logger.debug("Connected to RabbitMQ #{inspect metadata}")
    {:ok, new_state}
  end

  @doc false
  def consume(
    chan,
    %State{channel: %Channel{name: {exchange, routing_key}}} = state
  ) do
    {:ok, %{queue: queue}} = AMQP.Queue.declare(chan, "", exclusive: true)
    :ok = AMQP.Queue.bind(chan, queue, exchange, routing_key: routing_key)
    {:ok, _} = AMQP.Basic.consume(chan, queue)
    new_state = %State{state | chan: chan}
    {:ok, new_state}
  end

  @doc false
  def backoff(
    error,
    %State{channel: %Channel{name: {exchange, routing_key}}} = state
  ) do
    metadata = [channel: {exchange, routing_key}, error: error]
    Logger.error("Cannot connect to RabbitMQ #{inspect metadata}")
    {:backoff, 5_000, state}
  end

  @doc false
  def disconnected(
    %State{channel: %Channel{name: {exchange, routing_key}}} = state
  ) do
    metadata = [channel: {exchange, routing_key}]
    Logger.debug("Disconnected from RabbitMQ #{inspect metadata}")
    {:backoff, 5_000, state}
  end

  @doc false
  def terminated(
    reason,
    %State{channel: %Channel{name: {exchange, routing_key}}}
  ) do
    metadata = [channel: {exchange, routing_key}, error: reason]
    Logger.debug("Terminated RabbitMQ connection #{inspect metadata}")
    :ok
  end
end
