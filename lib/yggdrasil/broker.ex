defmodule Yggdrasil.Broker do
  @moduledoc """
  A server to manage the subscriptions inside Yggdrasil.
  """
  use GenServer

  require Logger

  alias Yggdrasil.Distributor.Generator
  alias Yggdrasil.Distributor.Backend

  ##
  # Broker state:
  #   - `subscribers` ETS table (non-persistent):
  #     pid -> monitor reference
  #   - `monitors` ETS table (persistent):
  #     channel -> number of subscribers
  #     {pid, channel} -> monitor reference
  #   - `generator` Distributor generator supervisor.
  defstruct [:subscribers, :monitors, :generator]
  alias __MODULE__, as: State

  #############################################################################
  # Client API.

  @doc """
  Starts the `Broker`. Receives the `generator` PID or name and a ETS table
  `monitors` to store the information of the subscribers. Optionally receives
  a list of `GenServer` `options`.
  """
  def start_link(generator, monitors, options \\ []) do
    state = %State{monitors: monitors, generator: generator}
    GenServer.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops the `broker` with a PID or name and an optional `reason`. By default is
  `:normal`.
  """
  def stop(broker, reason \\ :normal) do
    GenServer.stop(broker, reason)
  end

  @doc """
  Asks the `broker` to subscribe the calling process to a `channel`.
  """
  def subscribe(broker, channel) do
    subscribe(broker, channel, self())
  end

  @doc """
  Asks the `broker` to subscribe the `pid` to a `channel`.
  """
  def subscribe(broker, channel, pid) do
    GenServer.call(broker, {:subscribe, channel, pid})
  end

  @doc """
  Asks the `broker` to unsubscribe the calling process to a `channel`.
  """
  def unsubscribe(broker, channel) do
    unsubscribe(broker, channel, self())
  end

  @doc """
  Asks the `broker` to unsubscribe the `pid` to a `channel`.
  """
  def unsubscribe(broker, channel, pid) do
    GenServer.call(broker, {:unsubscribe, channel, pid})
  end

  #############################################################################
  # Callback definitions.

  @doc false
  def init(%State{} = state) do
    subscribers = :ets.new(:subscribers, [:set, read_concurrency: true,
                                          write_concurrency: true])
    new_state = %State{state | subscribers: subscribers}
    do_restart(new_state)
    {:ok, new_state}
  end

  @doc false
  def handle_call({:subscribe, channel, pid}, _from, %State{} = state) do
    result = do_subscribe(channel, pid, state)
    {:reply, result, state}
  end
  def handle_call({:unsubscribe, channel, pid}, _from, %State{} = state) do
    result = do_unsubscribe(channel, pid, state)
    {:reply, result, state}
  end
  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def handle_info({:DOWN, _, _, pid, _}, %State{monitors: monitors} = state) do
    channels = do_get_channels(monitors, pid)
    for channel <- channels do
      :ok = do_unsubscribe(channel, pid, state)
    end
    {:noreply, state}
  end
  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(%State{} = state, :normal) do
    do_stop(state)
    :ok
  end
  def terminate(_, _) do
    :ok
  end

  #############################################################################
  # Helpers.

  @doc false
  def do_restart(%State{monitors: monitors} = state) do
    info = monitors |> :ets.match({{:"$1", :"$2"}, :"_"})
    for [pid, channel] <- info do
      _ = :ets.delete(monitors, pid)
      if Process.alive?(pid) do
        do_subscribe!(channel, pid, state)
      else
        key = {pid, channel}
        _ = :ets.delete(monitors, key)
      end
    end
  end

  @doc false
  def do_subscribe!(channel, pid, %State{} = state) do
    case do_subscribe(channel, pid, state) do
      :ok -> :ok
      error -> exit(error)
    end
  end

  @doc false
  def do_subscribe(channel, pid, %State{} = state) do
    case start_distributor(channel, state) do
      {:ok, {:already_connected, _}} ->
        Logger.debug(fn ->
          "#{inspect pid} subscribed to #{inspect channel}"
        end)
        add_subscriber(channel, pid, state)
        Backend.connected(channel, pid)
        :ok
      {:ok, _} ->
        Logger.debug(fn ->
          "#{inspect pid} subscribed to #{inspect channel}"
        end)
        add_subscriber(channel, pid, state)
        :ok
      error ->
        Logger.error(fn ->
          "#{inspect pid} couldn't subscribed to #{inspect channel}"
        end)
        error
    end
  end

  @doc false
  def start_distributor(channel, %State{generator: generator}) do
    Generator.start_distributor(generator, channel)
  end

  @doc false
  def add_subscriber(
    channel,
    pid,
    %State{subscribers: subscribers, monitors: monitors}
  ) do
    case monitor(monitors, channel, pid) do
      {:error, _} ->
        subscribers |> :ets.lookup(channel) |> List.first()
      :ok ->
        :ets.update_counter(subscribers, channel, {2, 1}, {2, 0})
    end
  end

  @doc false
  def monitor(monitors, channel, pid) do
    ref = create_ref(monitors, pid)
    key = {pid, channel}
    case :ets.lookup(monitors, key) do
      [{^key, ^ref} | _] ->
        {:error, :already_monitored}
      _ ->
        :ets.insert(monitors, {key, ref})
        :ok
    end
  end

  @doc false
  def create_ref(monitors, pid) do
    case :ets.lookup(monitors, pid) do
    [{^pid, ref} | _] ->
      ref
    [] ->
      ref = Process.monitor(pid)
      :ets.insert(monitors, {pid, ref})
      ref
    end
  end

  @doc false
  def do_unsubscribe(channel, pid, %State{} = state) do
    case remove_subscriber(channel, pid, state) do
      counter when counter > 0 ->
        Logger.debug(fn ->
          "#{inspect pid} unsubscribed to #{inspect channel}"
        end)
        :ok
      _ ->
        Logger.debug(fn ->
          "Stopping distributor for #{inspect channel}"
        end)
        stop_distributor(channel)
        :ok
    end
  end

  @doc false
  def stop_distributor(channel) do
    Generator.stop_distributor(channel)
  end

  @doc false
  def remove_subscriber(
    channel,
    pid,
    %State{subscribers: subscribers, monitors: monitors}
  ) do
    demonitor(monitors, channel, pid)
    case :ets.update_counter(subscribers, channel, {2, -1}, {2, 0}) do
      counter when counter > 0 ->
        counter
      _ ->
        _ = :ets.delete(subscribers, channel)
        0
    end
  end

  @doc false
  def demonitor(monitors, channel, pid) do
    key = {pid, channel}
    case :ets.lookup(monitors, key) do
      [] ->
        {:error, :already_demonitored}
      [{^key, ref} | _] ->
        _ = :ets.delete(monitors, key)
        delete_ref(monitors, pid, ref)
        :ok
    end
  end

  @doc false
  def delete_ref(monitors, pid, ref) do
    case do_get_channels(monitors, pid) do
      [] ->
        Process.demonitor(ref)
        _ = :ets.delete(monitors, pid)
        :ok
      _ ->
        :ok
    end
  end

  @doc false
  def do_get_channels(monitors, pid) do
    monitors |> :ets.match({{pid, :"$1"}, :"_"}) |> List.flatten()
  end

  @doc false
  def do_stop(%State{monitors: monitors} = state) do
    info = monitors |> :ets.match({{:"$1", :"$2"}, :"_"})
    for [pid, channel] <- info do
      :ok = do_unsubscribe(channel, pid, state)
    end
  end
end
