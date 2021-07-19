defmodule Yggdrasil.Subscriber.Manager do
  @moduledoc """
  Manages subscription to a channel.
  """
  use GenServer

  require Logger

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Generator

  @doc false
  defstruct [:status, :channel, :cache]
  alias __MODULE__, as: State

  @typedoc """
  Subscription status.
  """
  @type status :: :connected | :disconnected

  @typedoc false
  @type t :: %__MODULE__{
          status: status(),
          channel: Channel.t(),
          cache: reference()
        }

  ############
  # Public API

  @doc """
  Starts a manager with a `channel`.
  """
  @spec start_link(Channel.t(), pid()) :: GenServer.on_start()
  @spec start_link(Channel.t(), pid(), GenServer.options()) ::
          GenServer.on_start()
  def start_link(channel, pid, options \\ [])

  def start_link(%Channel{} = channel, first_pid, options) do
    GenServer.start_link(__MODULE__, [channel, first_pid], options)
  end

  @doc """
  Stops a `manager` with an optional `reason`.
  """
  @spec stop(GenServer.name()) :: :ok
  @spec stop(GenServer.name(), term()) :: :ok
  def stop(manager, reason \\ :normal)

  def stop(manager, reason) do
    GenServer.stop(manager, reason)
  end

  @doc """
  Adds a `pid` to the `channel`.
  """
  @spec add(Channel.t(), pid()) :: :ok | {:error, binary()}
  def add(channel, pid)

  def add(%Channel{} = channel, pid) do
    name = {__MODULE__, channel}

    case ExReg.whereis_name(name) do
      :undefined ->
        {:error, "Manager is not available for subscriptions"}

      manager ->
        GenServer.call(manager, {:add, pid})
    end
  catch
    :exit, {:timeout, _} ->
      {:error, "Manager is not available for subscriptions"}
  end

  @doc """
  Removes a `pid` from the `channel`.
  """
  @spec remove(Channel.t(), pid()) :: :ok | {:error, binary()}
  def remove(channel, pid)

  def remove(%Channel{} = channel, pid) do
    name = {__MODULE__, channel}

    case ExReg.whereis_name(name) do
      :undefined ->
        {:error, "Manager is not available for unsubscriptions"}

      manager ->
        GenServer.call(manager, {:remove, pid})
    end
  catch
    :exit, {:timeout, _} ->
      {:error, "Manager not available for unsubscriptions"}
  end

  @doc """
  Reports the connection of the adapter.
  """
  @spec connected(Channel.t()) :: :ok | {:error, binary()}
  def connected(channel)

  def connected(%Channel{} = channel) do
    name = {__MODULE__, channel}

    case ExReg.whereis_name(name) do
      :undefined ->
        {:error, "Manager is not available for subscriptions"}

      manager ->
        GenServer.call(manager, :connected)
    end
  end

  @doc """
  Reports the disconnection of the adapter.
  """
  @spec disconnected(Channel.t()) :: :ok | {:error, binary()}
  def disconnected(channel)

  def disconnected(%Channel{} = channel) do
    name = {__MODULE__, channel}

    case ExReg.whereis_name(name) do
      :undefined ->
        {:error, "Manager is not available for subscriptions"}

      manager ->
        GenServer.call(manager, :disconnected)
    end
  end

  @doc """
  Whether the `pid` is subscribed or not to the `channel`.
  """
  @spec subscribed?(Channel.t()) :: boolean()
  @spec subscribed?(Channel.t(), nil | pid()) :: boolean()
  def subscribed?(channel, pid \\ nil)

  def subscribed?(%Channel{} = channel, nil) do
    subscribed?(channel, self())
  end

  def subscribed?(%Channel{} = channel, pid) when is_pid(pid) do
    subscribed?(:connected, channel, pid) or
      subscribed?(:disconnected, channel, pid)
  end

  @doc false
  @spec subscribed?(status(), Channel.t(), pid()) :: boolean()
  def subscribed?(status, channel, pid)

  def subscribed?(status, %Channel{} = channel, pid) do
    pid in :pg.get_members(__MODULE__, {status, channel})
  end

  #####################
  # GenServer callbacks

  @impl GenServer
  def init(args)

  def init([%Channel{} = channel, first_pid]) do
    state = %State{
      status: :disconnected,
      channel: channel,
      cache: :ets.new(:monitored, [:set])
    }

    Logger.debug(fn -> "Started #{__MODULE__} for #{inspect(channel)}" end)

    {:ok, state, {:continue, {:first_pid, first_pid}}}
  end

  @impl GenServer
  def handle_continue(message, state)

  def handle_continue({:first_pid, pid}, %State{} = state) do
    do_join(pid, state)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(message, from, state)

  def handle_call(:connected, _from, %State{} = state) do
    new_state = do_connected(state)

    if has_subscribers?(new_state) do
      {:reply, :ok, new_state}
    else
      {:stop, :normal, :ok, new_state}
    end
  end

  def handle_call(:disconnected, _from, %State{} = state) do
    new_state = do_disconnected(state)

    if has_subscribers?(new_state) do
      {:reply, :ok, new_state}
    else
      {:stop, :normal, :ok, new_state}
    end
  end

  def handle_call({:add, pid}, _from, %State{} = state) do
    do_join(pid, state)

    if has_subscribers?(state) do
      {:reply, :ok, state}
    else
      {:stop, :normal, :ok, state}
    end
  end

  def handle_call({:remove, pid}, _from, %State{} = state) do
    do_leave(pid, state)

    if has_subscribers?(state) do
      {:reply, :ok, state}
    else
      {:stop, :normal, :ok, state}
    end
  end

  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(message, state)

  def handle_info({:DOWN, _, _, pid, _}, %State{} = state) do
    do_leave(pid, state)

    if has_subscribers?(state) do
      {:noreply, state}
    else
      {:stop, :normal, state}
    end
  end

  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(reason, state)

  def terminate(:normal, %State{channel: channel}) do
    Generator.stop_distributor(channel)

    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect(channel)}"
    end)
  end

  def terminate(reason, %State{channel: channel} = _state) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect(channel)} due to #{inspect(reason)}"
    end)
  end

  ########################
  # Subscription functions

  @spec has_subscribers?(State.t()) :: boolean()
  defp has_subscribers?(state)

  defp has_subscribers?(%State{status: status, channel: channel}) do
    [] != :pg.get_members(__MODULE__, {status, channel})
  end

  ######################
  # Connection functions

  @spec do_connected(State.t()) :: State.t()
  defp do_connected(state)

  defp do_connected(%State{channel: channel} = state) do
    name = {:disconnected, channel}
    members = :pg.get_members(__MODULE__, name)

    do_leave(members, state)

    new_state = %State{state | status: :connected}
    do_join(members, new_state)

    new_state
  end

  @spec do_disconnected(State.t()) :: State.t()
  defp do_disconnected(state)

  defp do_disconnected(%State{channel: channel} = state) do
    name = {:connected, channel}
    members = :pg.get_members(__MODULE__, name)

    do_leave(members, state)

    new_state = %State{state | status: :disconnected}
    do_join(members, new_state)

    new_state
  end

  ##############
  # PG functions

  @spec do_join(pid() | [pid()], State.t()) :: :ok
  defp do_join(pid, state)

  defp do_join([], %State{} = _state) do
    :ok
  end

  defp do_join([_ | _] = pids, %State{} = state) do
    Enum.each(pids, fn pid -> do_join(pid, state) end)
  end

  defp do_join(pid, %State{status: status, channel: channel} = state)
       when is_pid(pid) do
    name = {status, channel}
    members = :pg.get_members(__MODULE__, name)

    monitor(pid, state)

    if pid not in members do
      :pg.join(__MODULE__, name, pid)
      if status == :connected, do: Backend.connected(channel, pid)
    end

    :ok
  end

  @doc false
  @spec do_leave(pid() | [pid()], State.t()) :: :ok
  defp do_leave(pid, state)

  defp do_leave([], %State{} = _state) do
    :ok
  end

  defp do_leave([_ | _] = pids, %State{} = state) do
    Enum.each(pids, fn pid -> do_leave(pid, state) end)
  end

  defp do_leave(pid, %State{status: status, channel: channel} = state)
       when is_pid(pid) do
    name = {status, channel}
    members = :pg.get_members(__MODULE__, name)

    demonitor(pid, state)

    if pid in members do
      :pg.leave(__MODULE__, name, pid)
      if status == :connected, do: Backend.disconnected(channel, pid)
    end

    :ok
  end

  ######################
  # Monitoring functions

  @spec monitor(pid(), State.t()) :: :ok
  defp monitor(pid, state)

  defp monitor(pid, %State{cache: cache}) do
    with [] <- :ets.lookup(cache, pid) do
      ref = Process.monitor(pid)
      :ets.insert(cache, {pid, ref})
    end

    :ok
  end

  @spec demonitor(pid(), State.t()) :: :ok
  defp demonitor(pid, state)

  defp demonitor(pid, %State{cache: cache}) do
    with [{^pid, ref} | _] <- :ets.lookup(cache, pid) do
      :ets.delete(cache, pid)
      Process.demonitor(ref)
    end

    :ok
  end
end
