defmodule Yggdrasil.Broker do
  @moduledoc """
  A server to manage the subscriptions inside Yggdrasil.
  """
  use GenServer
  alias Yggdrasil.Publisher.Generator

  ##
  # Broker state
  #
  # `:subscribers` ETS table (non-persistent):
  #   pid -> monitor reference
  # `:monitors` ETS table (persistent):
  #   channel -> number of subscribers
  #   {pid, channel} -> monitor reference
  # `:generator`: Publisher generator supervisor
  defstruct [:subscribers, :monitors, :generator]
  alias __MODULE__, as: Broker

  ###################
  # Client functions.

  @doc """
  Starts the broker. Receives the `generator` and a `:ets` table `monitors` to
  store information of the subscribers and `opts` a list of `GenServer`
  options.
  """
  def start_link(generator, monitors, opts \\ []) do
    state = %Broker{monitors: monitors, generator: generator}
    GenServer.start_link(__MODULE__, state, opts)
  end

  @doc """
  Stops the broker `server` with a `reason`. By default `reason` is `:normal`.
  """
  def stop(server, reason \\ :normal) do
    GenServer.stop(server, reason)
  end

  @doc """
  Sends a request to `server` to subscribe the current process to a `channel`.
  """
  def subscribe(server, channel) do
    pid = self()
    subscribe(server, channel, pid)
  end

  @doc """
  Sends a request to `server` to subscribe the process `pid` to a `channel`.
  """
  def subscribe(server, channel, pid) do
    pid = if is_nil(pid), do: self(), else: pid
    GenServer.call(server, {:subscribe, channel, pid})
  end

  @doc """
  Sends a request to `server` to unsubscribe the current process from a
  `channel`.
  """
  def unsubscribe(server, channel) do
    pid = self()
    unsubscribe(server, channel, pid)
  end

  @doc """
  Sends a request to `server` to unsubscribe the process `pid` from a
  `channel`.
  """
  def unsubscribe(server, channel, pid) do
    GenServer.call(server, {:unsubscribe, channel, pid})
  end

  @doc """
  Sends a request to `server` to get the channels where the current process is
  subscribed.
  """
  def get_channels(server) do
    pid = self()
    get_channels(server, pid)
  end

  @doc """
  Sends a request to `server` to get the channels where the process `pid` is
  subscribed.
  """
  def get_channels(server, pid) do
    GenServer.call(server, {:channels, pid})
  end

  @doc """
  Sends a request to `server` to get the subscribers of a `channel`.
  """
  def get_subscribers(server, channel) do
    GenServer.call(server, {:subscribers, channel})
  end

  @doc """
  Sends a request to `server` to counts the number of subscribers for a
  `channel`.
  """
  def count_subscribers(server, channel) do
    GenServer.call(server, {:count, channel})
  end

  ###################
  # Helper functions.

  ##
  # Gets or creates a monitor reference from a `pid`
  defp create_ref(monitors, pid) do
    case :ets.lookup(monitors, pid) do
      [{^pid, ref} | _] ->
        ref
      [] -> 
        ref = Process.monitor(pid)
        :ets.insert(monitors, {pid, ref})
        ref
    end
  end

  ##
  # Monitors a `pid` subscribed to a `channel`.
  defp monitor(monitors, channel, pid) do
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

  ##
  # Adds a subscriber `pid` to a `channel`.
  defp add_subscriber(
    channel,
    pid,
    %Broker{subscribers: subscribers, monitors: monitors}
  ) do
    case monitor(monitors, channel, pid) do
      {:error, :already_monitored} ->
        subscribers |> :ets.lookup(channel) |> List.first()
      :ok ->
        :ets.update_counter(subscribers, channel, {2, 1}, {2, 0})
    end
  end

  ##
  # Gets monitor referece from a `pid`.
  defp delete_ref(monitors, pid, ref) do
    case do_get_channels(monitors, pid) do
      [] ->
        Process.demonitor(ref)
        _ = :ets.delete(monitors, pid)
      _ ->
        :ok
    end
  end

  ##
  # Demonitors a `pid` subscribed to a `channel`
  defp demonitor(monitors, channel, pid) do
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

  ##
  # Removes a subscriber `pid` from a `channel`.
  defp remove_subscriber(
    channel,
    pid,
    %Broker{subscribers: subscribers, monitors: monitors}
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

  ##
  # Subscribes a process `pid` to a `channel`.
  defp do_subscribe(channel, pid, %Broker{} = state) do
    case start_publisher(channel, state) do
      {:ok, _} ->
        add_subscriber(channel, pid, state)
        :ok
      error -> error
    end
  end

  ##
  # Subscribes a process `pid` to a `channel`. Exits the process on error.
  defp do_subscribe!(channel, pid, %Broker{} = state) do
    case do_subscribe(channel, pid, state) do
      :ok -> :ok
      error -> exit(error)
    end
  end

  ##
  # Starts the publisher.
  defp start_publisher(channel, %Broker{generator: generator}) do
    Generator.start_publisher(generator, channel)
  end

  ##
  # Unsubscribes a process `pid` to a `channel`.
  defp do_unsubscribe(channel, pid, %Broker{} = state) do
    case remove_subscriber(channel, pid, state) do
      counter when counter > 0 -> :ok
      _ -> stop_publisher(channel)
    end
  end

  ##
  # Stops the publisher.
  defp stop_publisher(channel) do
    Generator.stop_publisher(channel)
  end

  ##
  # Stablishes consistency on restart.
  defp restart(%Broker{monitors: monitors} = state) do
    info = :ets.match(monitors, {{"$1", :"$2"}, :"_"})
    for [pid, channel] <- info do
      _ = :ets.delete(monitors, pid)
      if Process.alive?(pid) do
        do_subscribe!(channel, pid, state)
      else
        key = {pid, channel}
        _ = :ets.delete(monitors, key)
      end
    end
    :ok
  end

  ##
  # Gets channels where the process `pid` is subscribed.
  defp do_get_channels(monitors, pid) do
    monitors |> :ets.match({{pid, :"$1"}, :"_"}) |> List.flatten
  end

  ##
  # Gets the subscribers to a `channel`.
  defp do_get_subscribers(monitors, channel) do
    monitors |> :ets.match({{:"$1", channel}, :"_"}) |> List.flatten
  end

  ##
  # Counts the number of subscribers for a `channel`.
  defp do_count_subscribers(subscribers, channel) do
    case :ets.lookup(subscribers, channel) do
      [] -> 0
      [{^channel, count}] -> count
    end
  end

  ##
  # Stops all publishers.
  defp do_stop(monitors, %Broker{} = state) do
    info = monitors |> :ets.match({{:"$1", :"$2"}, :"_"})
    for [pid, channel] <- info do
      :ok = do_unsubscribe(channel, pid, state)
    end
  end

  ######################
  # Callback definition.

  @doc false
  def init(%Broker{} = state) do
    subscribers = :ets.new(:subscribers, [:set, read_concurrency: true,
                                          write_concurrency: false])
    new_state = %Broker{state | subscribers: subscribers}
    restart(new_state)
    {:ok, new_state}
  end

  @doc false
  def handle_call({:subscribe, channel, pid}, _from, %Broker{} = state) do
    result = do_subscribe(channel, pid, state)
    {:reply, result, state}
  end
  def handle_call({:unsubscribe, channel, pid}, _from, %Broker{} = state) do
    :ok = do_unsubscribe(channel, pid, state)
    {:reply, :ok, state}
  end
  def handle_call({:channels, pid}, _from, %Broker{} = state) do
    channels = do_get_channels(state.monitors, pid)
    {:reply, channels, state}
  end
  def handle_call({:subscribers, channel}, _from, %Broker{} = state) do
    subscribers = do_get_subscribers(state.monitors, channel)
    {:reply, subscribers, state}
  end
  def handle_call({:count, channel}, _from, %Broker{} = state) do
    count = do_count_subscribers(state.subscribers, channel)
    {:reply, count, state}
  end
  def handle_call(_msg, _from, %Broker{} = state) do
    {:noreply, state}
  end

  @doc false
  def handle_info({:DOWN, _, _, pid, _}, %Broker{monitors: monitors} = state) do
    channels = do_get_channels(monitors, pid)
    for channel <- channels do
      :ok = do_unsubscribe(channel, pid, state)
    end
    {:noreply, state}
  end
  def handle_info(_msg, %Broker{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(%Broker{} = state, :normal) do
    do_stop(state, state)
    :ok
  end
  def terminate(_, _) do
    :ok
  end
end
