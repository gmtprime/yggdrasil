defmodule Yggdrasil.Messenger do
  use GenServer
  require Logger
  alias Yggdrasil.Proxy, as: Proxy
  alias Yggdrasil.Util.Forwarder, as: Forwarder

  #############
  # Client API.

  @doc """
  Starts a new messenger. Receives a `broker`(module name), a `channel` id and
  a `proxy` to resend the messages.
  """
  def start_link(broker, channel, proxy, forwarder \\ nil, opts \\ []) do
    args = %{module: broker, channel: channel, proxy: proxy,
             forwarder: forwarder}
    GenServer.start_link __MODULE__, args, opts
  end


  @doc """
  Stops the messenger.
  """
  def stop(messenger) do
    GenServer.call(messenger, :stop)
  end

  ###################
  # Server callbacks.

  def init(args) do
    pid = self()
    state = case args.module.subscribe args.channel, &(send pid, &1) do
      {:ok, conn} ->
        Map.put_new(args, :conn, conn) |> Map.put_new(:interval, :none)
      {:ok, conn, interval} ->
        Map.put_new(args, :conn, conn)
        |> Map.put_new(:interval, interval)
        |> Map.put_new(:cache, :new)
    end
    advertise_broker args.forwarder, state.conn
    {:ok, state}
  end


  def handle_call(:stop, _from, state), do:
    {:stop, :normal, :ok, state}

  def handle_call({:stop, reason}, _from, state), do:
    {:stop, reason, :ok, state}

  def handle_call(_other, _from, state), do:
    {:reply, :not_implemented, state}
  

  def handle_cast({:stop, reason}, state), do:
    {:stop, reason, :ok, state}

  def handle_cast(:subscribed, state) do
    subscribed state.forwarder, state.module, state.channel
    {:noreply, state}
  end

  def handle_cast({:message, message}, state) do
    Proxy.publish state.proxy, state.module, state.channel, message
    received state.forwarder, state.module, state.channel, message
    {:noreply, state}
  end

  def handle_cast(_other, state), do:
    {:noreply, state}


  def handle_info(:handle_message, %{cache: :new} = state) do
    # No first message in the cache.
    pid = self()
    Process.send_after pid, :handle_message, state.interval
    {:noreply, state}
  end

  def handle_info(:handle_message, %{cache: nil} = state) do
    # No new messages in the cache.
    pid = self()
    Process.send_after pid, :handle_message, state.interval
    {:noreply, state}
  end

  def handle_info(:handle_message, %{cache: message} = state) do
    # Send new message in cache.
    pid = self()
    spawn fn -> reroute_message pid, message end
    Process.send_after pid, :handle_message, state.interval
    {:noreply, %{state | cache: nil}}
  end

  def handle_info(message, %{interval: :none} = state) do
    # No interval set
    pid = self()
    real_message = state.module.handle_message state.conn, message
    spawn fn -> reroute_message pid, real_message end
    {:noreply, state}
  end

  def handle_info(message, %{cache: :new} = state) do
    # Cache is new. First message should be sent ASAP.
    pid = self()
    real_message = state.module.handle_message state.conn, message
    spawn fn -> reroute_message pid, real_message end
    if real_message == :subscribed do
      {:noreply, state}
    else
      Process.send_after pid, :handle_message, state.interval
      {:noreply, %{state | cache: nil}}
    end
  end

  def handle_info(message, state) do
    real_message = state.module.handle_message state.conn, message
    if is_valid?(real_message) do
      {:noreply, %{state | cache: real_message}}
    else
      {:noreply, state}
    end
  end


  def terminate(_, state) do
    state.module.unsubscribe state.conn
    unsubscribed state.forwarder, state.module, state.channel
  end

  #############
  # Server API.

  ##
  # Reroute `message` to `pid`.
  defp reroute_message(pid, message) do
    if is_valid?(message) do
      GenServer.cast pid, message
    else
      nil
    end
  end

  ##
  # Whether the message is valid or not.
  defp is_valid?(message) do
    case message do
      :subscribed -> true
      {:message, _} -> true
      _ -> false
    end
  end

  ##
  # Testing purposes. Triggers an event to inform the broker connection
  # handler.
  defp advertise_broker(nil, _conn), do:
    :ok
  defp advertise_broker(forwarder, conn), do:
    Forwarder.notify forwarder, {:broker_conn, conn}

  ##
  # Testing purposes. Triggers an event to inform a message has been received.
  defp received(nil, _broker, _channel, _data), do:
    :ok
  defp received(forwarder, broker, channel, data) do
    Forwarder.notify forwarder, {:message, broker, channel, data}
  end

  ##
  # Testing purposes. Triggers an event to inform the server subscribed to a
  # channel.
  defp subscribed(nil, _broker, _channel), do:
    :ok
  defp subscribed(forwarder, broker, channel) do
    Logger.info "Subscribed to #{inspect channel} [broker #{inspect broker}]."
    Forwarder.notify forwarder, {:subscribed, broker, channel}
  end

  ##
  # Testing purposes. Triggers an event to inform the server unsubscribed from
  # a channel.
  defp unsubscribed(nil, _broker, _channel), do:
    :ok
  defp unsubscribed(forwarder, broker, channel) do
    Logger.info "Unsubscribed from #{inspect channel} [broker #{inspect broker}]."
    Forwarder.notify forwarder, {:unsubscribed, broker, channel}
  end
end
