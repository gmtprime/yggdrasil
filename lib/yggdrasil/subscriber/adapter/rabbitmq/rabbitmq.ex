defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil subscriber adapter for RabbitMQ. The name of the channel should be
  a tuple with the name of the exchange and the routing key. The exchange
  should be a topic (or any exchange that redirects to topic) e.g:

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
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection, as: Conn

  alias AMQP.Queue
  alias AMQP.Basic

  defstruct [:publisher, :channel, :chan, :queue]
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
  def init(%State{channel: %Channel{name: {_, _}} = channel} = state) do
    Process.flag(:trap_exit, true)
    Logger.debug(fn -> "Started #{__MODULE__} for #{inspect channel}" end)
    {:connect, :init, state}
  end

  @doc false
  def connect(_, %State{channel: %Channel{namespace: namespace}} = state) do
    with {:ok, _} <- Generator.connect(namespace),
         {:ok, new_state} <- open_channel(state) do
      connected(new_state)
    else
      error ->
        backoff(error, state)
    end
  end

  @doc false
  def disconnect(_info, %State{chan: nil} = state) do
    disconnected(state)
  end
  def disconnect(
    info,
    %State{chan: chan, channel: %Channel{} = channel} = state
  ) do
    Backend.disconnected(channel)
    if Process.alive?(chan.pid) do
      Generator.close_channel(chan)
    end
    disconnect(info, %State{state | chan: nil})
  end

  @doc false
  def handle_info({:basic_consume_ok, _}, %State{} = state) do
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
  def terminate(
    reason,
    %State{chan: chan, channel: %Channel{} = channel} = state
  ) do
    Backend.disconnected(channel)
    if Process.alive?(chan.pid) do
      Generator.close_channel(chan)
    end
    terminate(reason, %State{state | chan: nil})
  end

  #########
  # Helpers

  @doc false
  def rabbitmq_options(%Channel{namespace: namespace}) do
    Conn.rabbitmq_options(namespace)
  end

  @doc false
  def connected(%State{channel: %Channel{} = channel} = state) do
    try do
      with {:ok, new_state} <- declare_queue(state),
           :ok <- consume(new_state) do
        Logger.debug(fn ->
          "#{__MODULE__} connected to RabbitMQ #{inspect channel}"
        end)
        Backend.connected(channel)
        {:ok, new_state}
      else
        error ->
          backoff(error, state)
      end
    catch
      :error, error ->
        backoff({:error, error}, state)
      error, reason ->
        backoff({:error, {error, reason}}, state)
    end
  end

  @doc false
  def open_channel(
    %State{channel: %Channel{namespace: namespace}, chan: nil} = state
  ) do
    with {:ok, chan} <- Generator.open_channel(namespace) do
      _ = Process.monitor(chan.pid)
      new_state = %State{state | chan: chan}
      {:ok, new_state}
    end
  end
  def open_channel(%State{chan: chan} = state) do
    if Process.alive?(chan.pid) do
      Generator.close_channel(chan)
    end
    open_channel(%State{state | chan: nil})
  end

  @doc false
  def declare_queue(%State{chan: chan} = state) do
    with {:ok, %{queue: queue}} <- Queue.declare(chan, "", exclusive: true) do
      new_state = %State{state | queue: queue}
      {:ok, new_state}
    end
  end

  @doc false
  def consume(
    %State{
      chan: chan,
      queue: queue,
      channel: %Channel{name: {exchange, routing_key}}
    }
  ) do
    with :ok <- Queue.bind(chan, queue, exchange, routing_key: routing_key),
         {:ok, _} <- Basic.consume(chan, queue) do
      :ok
    end
  end

  @doc false
  def backoff(
    {:backoff, new_backoff},
    %State{chan: nil, channel: %Channel{} = channel} = state
  ) do
    Logger.warn(fn ->
      "#{__MODULE__} cannot connect to RabbitMQ for #{inspect channel}" <>
      " waiting backoff of #{inspect new_backoff} ms"
    end)
    {:backoff, new_backoff, state}
  end
  def backoff(
    error,
    %State{chan: nil, channel: %Channel{} = channel} = state
  ) do
    Logger.warn(fn ->
      "#{__MODULE__} cannot connect to RabbitMQ for #{inspect channel}" <>
      " due to #{inspect error}"
    end)
    {:backoff, 5_000, state}
  end
  def backoff(error, %State{chan: chan} = state) do
    if Process.alive?(chan.pid) do
      Generator.close_channel(chan)
    end
    new_state = %State{state | chan: nil}
    backoff(error, new_state)
  end

  @doc false
  def disconnected(%State{channel: %Channel{} = channel} = state) do
    Logger.warn(fn ->
      "#{__MODULE__} disconnected from RabbitMQ #{inspect channel}"
    end)
    {:backoff, 5_000, state}
  end

  @doc false
  def terminated(:normal, %State{channel: %Channel{} = channel}) do
    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect channel}"
    end)
  end
  def terminated(reason, %State{channel: %Channel{} = channel}) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect channel} due to #{inspect reason}"
    end)
  end
end
