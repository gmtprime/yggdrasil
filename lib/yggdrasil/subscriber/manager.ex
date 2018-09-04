defmodule Yggdrasil.Subscriber.Manager do
  @moduledoc """
  Manages subscription to a channel.
  """
  use GenServer

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Settings
  alias Yggdrasil.Backend
  alias Yggdrasil.Subscriber.Generator

  @registry Settings.yggdrasil_process_registry()

  defstruct [:status, :channel, :cache]
  alias __MODULE__, as: State
  @type t :: %__MODULE__{
    status: atom(),
    channel: Channel.t(),
    cache: reference()
  }

  ############
  # Public API

  @doc """
  Starts a manager with a `channel`.
  """
  @spec start_link(
    channel :: Channel.t()
  ) :: GenServer.on_start()
  @spec start_link(
    channel :: Channel.t(),
    GenServer.options()
  ) :: GenServer.on_start()
  def start_link(channel, options \\ [])

  def start_link(%Channel{} = channel, options) do
    GenServer.start_link(__MODULE__, channel, options)
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
  @spec add(Channel.t(), pid()) :: :ok | {:error, term()}
  def add(channel, pid)

  def add(%Channel{} = channel, pid) do
    name = {__MODULE__, channel}
    case @registry.whereis_name(name) do
      :undefined ->
        {:error, "Manager is not available for subscriptions"}
      manager ->
        GenServer.call(manager, {:add, pid})
    end
  end

  @doc """
  Removes a `pid` from the `channel`.
  """
  @spec remove(Channel.t(), pid()) :: :ok | {:error, term()}
  def remove(channel, pid)

  def remove(%Channel{} = channel, pid) do
    name = {__MODULE__, channel}
    case @registry.whereis_name(name) do
      :undefined ->
        {:error, "Manager is not available for unsubscriptions"}
      manager ->
        GenServer.call(manager, {:remove, pid})
    end
  end

  @doc """
  Reports the connection of the adapter.
  """
  def connected(%Channel{} = channel) do
    name = {__MODULE__, channel}
    case @registry.whereis_name(name) do
      :undefined ->
        {:error, "Manager is not available for subscriptions"}
      manager ->
        GenServer.call(manager, :connected)
    end
  end

  @doc """
  Reports the disconnection of the adapter.
  """
  def disconnected(%Channel{} = channel) do
    name = {__MODULE__, channel}
    case @registry.whereis_name(name) do
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
  @spec subscribed?(Channel.t(), pid()) :: boolean()
  def subscribed?(channel, pid \\ nil)

  def subscribed?(%Channel{} = channel, nil) do
    subscribed?(channel, self())
  end
  def subscribed?(%Channel{} = channel, pid) when is_pid(pid) do
    subscribed?(:connected, channel, pid) or
    subscribed?(:disconnected, channel, pid)
  end

  #####################
  # GenServer callbacks

  @impl true
  def init(%Channel{} = channel) do
    state = %State{
      status: :connected,
      channel: channel,
      cache: :ets.new(:monitored, [:set])
    }
    :pg2.create({:connected, channel})
    :pg2.create({:disconnected, channel})
    with {:ok, new_state} <- do_disconnected(state) do
      Logger.debug(fn -> "Started #{__MODULE__} for #{inspect channel}" end)
      {:ok, new_state}
    else
      :stop ->
        {:stop, :normal}
    end
  end

  @impl true
  def handle_call(:connected, _from, %State{} = state) do
    with {:ok, new_state} <- do_connected(state),
         :ok <- check_subscribers(new_state) do
      {:reply, :ok, new_state}
    else
      :stop ->
        {:stop, :normal, :ok, state}
    end
  end
  def handle_call(:disconnected, _from, %State{} = state) do
    with {:ok, new_state} <- do_disconnected(state),
         :ok <- check_subscribers(new_state) do
      {:reply, :ok, new_state}
    else
      :stop ->
        {:stop, :normal, :ok, state}
    end
  end
  def handle_call({:add, pid}, _from, %State{} = state) do
    with :ok <- join([pid], state),
         :ok <- check_subscribers(state) do
      {:reply, :ok, state}
    else
      :stop ->
        {:stop, :normal, :ok, state}
    end
  end
  def handle_call({:remove, pid}, _from, %State{} = state) do
    with :ok <- leave([pid], state),
         :ok <- check_subscribers(state) do
      {:reply, :ok, state}
    else
      :stop ->
        {:stop, :normal, :ok, state}
    end
  end
  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _, _, pid, _}, %State{} = state) do
    if leave([pid], state) > 0 do
      {:noreply, state}
    else
      {:stop, :normal, state}
    end
  end
  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def terminate(:normal, %State{channel: channel}) do
    :pg2.delete({:connected, channel})
    :pg2.delete({:disconnected, channel})
    Generator.stop_distributor(channel)
    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect channel}"
    end)
  end
  def terminate(reason, %State{channel: channel} = _state) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect channel} due to #{inspect reason}"
    end)
  end

  #################
  # General helpers

  @doc false
  def subscribed?(type, %Channel{} = channel, pid) do
    name = {type, channel}
    case :pg2.get_members(name) do
      {:error, {:no_such_group, _}} ->
        false
      members when is_list(members) ->
        pid in members
    end
  end

  @doc false
  def check_subscribers(%State{status: status, channel: channel}) do
    name = {status, channel}
    if length(:pg2.get_members(name)) > 0 do
      :ok
    else
      :stop
    end
  end

  ######################
  # Connection functions

  @doc false
  def do_connected(%State{channel: channel} = state) do
    name = {:disconnected, channel}
    members = :pg2.get_members(name)
    leave(members, state)
    new_state = %State{state | status: :connected}
    join(members, new_state)
    {:ok, new_state}
  end

  @doc false
  def do_disconnected(%State{channel: channel} = state) do
    name = {:connected, channel}
    members = :pg2.get_members(name)
    leave(members, state)
    new_state = %State{state | status: :disconnected}
    join(members, new_state)
    {:ok, new_state}
  end

  ################
  # Join functions

  @doc false
  @spec join([pid()], State.t()) :: :ok
  def join(pids, state)

  def join([], _) do
    :ok
  end
  def join([pid | pids], %State{} = state) do
    do_join(pid, state)
    join(pids, state)
  end

  @doc false
  @spec do_join(pid(), State.t()) :: :ok
  def do_join(pid, %State{status: :connected, channel: channel} = state) do
    name = {:connected, channel}
    members = :pg2.get_members(name)
    monitor(pid, state)
    if not (pid in members) do
      :pg2.join(name, pid)
      Backend.connected(channel, pid)
    end
    :ok
  end
  def do_join(pid, %State{status: :disconnected, channel: channel} = state) do
    name = {:disconnected, channel}
    members = :pg2.get_members(name)
    monitor(pid, state)
    if not (pid in members) do
      :pg2.join(name, pid)
    end
    :ok
  end

  @doc false
  @spec monitor(pid(), State.t()) :: :ok
  def monitor(pid, state)

  def monitor(pid, %State{cache: cache}) do
    with [] <- :ets.lookup(cache, pid) do
      ref = Process.monitor(pid)
      :ets.insert(cache, {pid, ref})
    end
    :ok
  end

  #################
  # Leave functions

  @doc false
  @spec leave([pid()], State.t()) :: :ok
  def leave(pids, state)

  def leave([], _) do
    :ok
  end
  def leave([pid | pids], %State{} = state) do
    do_leave(pid, state)
    leave(pids, state)
  end

  @doc false
  @spec do_leave(pid(), State.t()) :: :ok
  def do_leave(pid, state)

  def do_leave(pid, %State{status: :connected, channel: channel} = state) do
    name = {:connected, channel}
    members = :pg2.get_members(name)
    demonitor(pid, state)
    if pid in members do
      :pg2.leave(name, pid)
      Backend.disconnected(channel, pid)
    end
    :ok
  end
  def do_leave(pid, %State{status: :disconnected, channel: channel} = state) do
    name = {:disconnected, channel}
    members = :pg2.get_members(name)
    demonitor(pid, state)
    if pid in members do
      :pg2.leave(name, pid)
    end
    :ok
  end

  @doc false
  @spec demonitor(pid(), State.t()) :: :ok
  def demonitor(pid, state)

  def demonitor(pid, %State{cache: cache}) do
    with [{^pid, ref} | _] <- :ets.lookup(cache, pid) do
      :ets.delete(cache, pid)
      Process.demonitor(ref)
    end
    :ok
  end
end
