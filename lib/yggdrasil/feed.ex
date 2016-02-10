defmodule Yggdrasil.Feed do
  use GenServer
  require Logger
  alias Yggdrasil.Proxy, as: Proxy
  alias Yggdrasil.Util.Forwarder, as: Forwarder

  #############
  # Client API.

  @doc """
  Starts a feed.

  Receives a `broker_sup`, a `proxy`, a subscribers table and a `refs` table.
  Aditionally it can receive a `forwarder` for testing purposes and a list of
  `options`. 
  """
  def start_link(broker_sup, proxy, subscribers, messengers,
                 forwarder \\ nil, options \\ []) do
    args = %{broker_sup: broker_sup, proxy: proxy, subscribers: subscribers,
             messengers: messengers, forwarder: forwarder}
    GenServer.start_link __MODULE__, args, options
  end

  def stop(feed) do
    GenServer.call feed, :stop
  end

  @doc """
  Sends a message to the `feed` to subscribe to a `channel` using `broker`.
  """
  def subscribe(feed, broker, channel, callback \\ nil) do
    case GenServer.call feed, {:subscribe, broker, channel} do
      {:ok, {:subscribed, proxy}} ->
        Proxy.subscribe proxy, broker, channel, callback
      error ->
        error
    end
  end

  @doc """
  Sends a message to the `feed` to unsubscribe from a `channel` of a
  `broker`.
  """
  def unsubscribe(feed, id) do
    case GenServer.call feed, {:unsubscribe, id.broker, id.channel} do
      {:ok, {:unsubscribed, proxy}} ->
        Proxy.unsubscribe proxy, id
      error ->
        error
    end
  end

  ###################
  # Server callbacks.

  def init(args) do
    refs = :ets.foldl(fn {{broker, channel}, pid}, acc ->
      if Process.alive? pid do
        Map.put acc, Process.monitor(pid), {{broker, channel}, pid}
      else
        {:ok, new_pid} = Yggdrasil.MessengerSupervisor.start_broker(
                           args.messengers,
                           broker,
                           channel,
                           args.proxy,
                           args.forwarder)
        :ets.insert args.messengers, {{broker, channel}, new_pid}
        Map.put acc, Process.monitor(new_pid), {{broker, channel}, new_pid}
      end
    end, Map.new, args.messengers)
    state = Map.put_new args, :refs, refs
    {:ok, state}
  end

  def handle_call(:stop, _from, state), do:
    {:stop, :normal, :ok, state} 
  def handle_call({:subscribe, broker, channel}, _from, state) do
    {:ok, %{state: new_state, counter: counter}} = add_subscriber broker,
                                                                  channel,
                                                                  state
    subscribers state.forwarder, broker, channel, counter
    {:reply, {:ok, {:subscribed, state.proxy}}, new_state}
  end
  def handle_call({:unsubscribe, broker, channel}, _from, state) do
    {:ok, %{state: new_state, counter: counter}} = remove_subscriber broker,
                                                                     channel,
                                                                     state
    subscribers state.forwarder, broker, channel, counter
    {:reply, {:ok, {:unsubscribed, state.proxy}}, new_state}
  end
  def handle_call(_other, _from, state), do:
    {:reply, :not_implemented, state}

  def handle_info({:DOWN, ref, :process, _, :normal}, state) do
    {_, refs} = Map.pop state.refs, ref
    {:noreply, %{state | refs: refs}}
  end
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    case Map.pop state.refs, ref do
      {:nil, _} ->
        {:noreply, state}
      {{{broker, channel}, ^pid}, refs} ->
        :ets.delete state.messengers, {broker, channel}
        new_state = %{state | refs: refs}
        {:ok, new_refs} = start_broker broker, channel, new_state
        restarted_broker state.forwarder, broker, channel
        {:noreply, %{new_state | refs: new_refs}}
    end
  end
  def handle_info(_, _, state), do:
    {:noreply, state}

  def terminate(:normal, state) do
    ids = :ets.foldl(fn {id, _}, acc -> [id | acc] end, [], state.messengers)
    ids |>
      Enum.map(fn {broker, channel} ->
        remove_subscriber(broker, channel, state)
      end)
    terminated state.forwarder, :normal, self()
  end
  def terminate(_, state), do:
    terminated state.forwarder, :unexpected, self()

  #############
  # Server API.

  ##
  # Starts a broker.
  defp start_broker(broker, channel, state) do
    {:ok, pid} = Yggdrasil.MessengerSupervisor.start_broker state.broker_sup,
                                                            broker,
                                                            channel,
                                                            state.proxy,
                                                            state.forwarder 
    :ets.insert state.messengers, {{broker, channel}, pid}
    refs = Map.put state.refs, Process.monitor(pid), {{broker, channel}, pid}
    {:ok, %{state | refs: refs}}
  end

  ##
  # Adds a subscriber to a channel of a broker.
  defp add_subscriber(broker, channel, state) do
    counter = :ets.update_counter state.subscribers,
                                  {broker, channel},
                                  {2, 1},
                                  {2, 0}
    case :ets.lookup state.messengers, {broker, channel} do
      [] ->
        {:ok, new_state} = start_broker broker, channel, state
        {:ok, %{state: new_state, counter: counter}}
      _ ->
        {:ok, %{state: state, counter: counter}}
    end
  end

  ##
  # Deletes a subscriber from a channel.
  defp remove_subscriber(broker, channel, state) do
    counter = :ets.update_counter state.subscribers,
                                  {broker, channel},
                                  {2, -1},
                                  {2, 0}
    if counter == 0 do
      case :ets.lookup state.messengers, {broker, channel} do
        [{{^broker, ^channel}, pid} | _] ->
          :ets.delete state.messengers, {broker, channel}
          :ets.delete state.subscribers, {broker, channel}
          Yggdrasil.Messenger.stop pid
        _ ->
          :ok
      end
    end
    {:ok, %{state: state, counter: counter}}
  end

  ##
  # Debugging purposes. Sends the number of subscribers to a channel.
  defp subscribers(nil, _broker, _channel, _counter), do:
    :ok
  defp subscribers(forwarder, broker, channel, counter), do:
    Forwarder.notify forwarder, {:subscribers, broker, channel, counter}

  ##
  # Debugging purposes. Sends a message informing the broker has been
  # restarted.
  defp restarted_broker(nil, _broker, _channel), do:
    :ok
  defp restarted_broker(forwarder, broker, channel), do:
    Forwarder.notify forwarder, {:restarted, broker, channel}

  ##
  # Debugging purposes. Sends message of server termination.
  defp terminated(nil, _reason, _pid), do:
    :ok
  defp terminated(forwarder, :normal, pid) do
    Logger.info "Feed terminated."
    Forwarder.notify forwarder, {:terminated, :normal, pid}
  end
  defp terminated(forwarder, :unexpected, pid) do
    Logger.error("Unexpected termination of Feed.")
    Forwarder.notify forwarder, {:terminated, :unexpected, pid}
  end
end
