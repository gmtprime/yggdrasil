defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil subscriber adapter for RabbitMQ. The name of the channel should be
  a tuple with the name of the exchange and the routing key. The exchange
  should be a topic (or any exchange that redirects to topic) e.g:

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
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection, as: Conn

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
  def rabbitmq_options(%Channel{namespace: namespace}) do
    Conn.rabbitmq_options(namespace)
  end

  @doc false
  def connected(
    chan,
    %State{channel: %Channel{name: {exchange, routing_key}}} = state
  ) do
    Process.monitor(chan.pid)
    {:ok, new_state} = consume(chan, state)
    metadata = [channel: {exchange, routing_key}]
    Logger.debug(fn ->
      "Connected to RabbitMQ #{inspect metadata}"
    end)
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
    Logger.error(fn ->
      "Cannot connect to RabbitMQ #{inspect metadata}"
    end)
    {:backoff, 5_000, state}
  end

  @doc false
  def disconnected(
    %State{channel: %Channel{name: {exchange, routing_key}}} = state
  ) do
    metadata = [channel: {exchange, routing_key}]
    Logger.debug(fn ->
      "Disconnected from RabbitMQ #{inspect metadata}"
    end)
    {:backoff, 5_000, state}
  end

  @doc false
  def terminated(
    reason,
    %State{channel: %Channel{name: {exchange, routing_key}}}
  ) do
    metadata = [channel: {exchange, routing_key}, error: reason]
    Logger.debug(fn ->
      "Terminated RabbitMQ connection #{inspect metadata}"
    end)
    :ok
  end
end
