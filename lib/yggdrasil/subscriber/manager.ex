defmodule Yggdrasil.Subscriber.Manager do
  @moduledoc """
  Manages subscription to a channel.
  """
  use GenServer

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Settings
  alias Yggdrasil.Subscriber.Generator

  @registry Settings.yggdrasil_process_registry()

  defstruct [:channel, :cache]
  alias __MODULE__, as: State
  @type t :: %__MODULE__{
    channel: Channel.t(),
    cache: reference()
  }

  ############
  # Public API

  @doc """
  Starts a manager with an initial `pid` and a `channel`.
  """
  @spec start_link(Channel.t(), pid()) :: GenServer.on_start()
  @spec start_link(
    Channel.t(),
    pid(),
    GenServer.options()
  ) :: GenServer.on_start()
  def start_link(channel, pid, options \\ [])

  def start_link(%Channel{} = channel, pid, options) do
    GenServer.start_link(__MODULE__, [channel, pid], options)
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
  Whether the `pid` is subscribed or not to the `channel`.
  """
  @spec subscribed?(Channel.t()) :: boolean()
  @spec subscribed?(Channel.t(), pid()) :: boolean()
  def subscribed?(channel, pid \\ nil)

  def subscribed?(%Channel{} = channel, nil) do
    subscribed?(channel, self())
  end
  def subscribed?(%Channel{} = channel, pid) when is_pid(pid) do
    case :pg2.get_members(channel) do
      {:error, {:no_such_group, _}} ->
        false
      members when is_list(members) ->
        pid in members
    end
  end

  #####################
  # GenServer callbacks

  @impl true
  def init([%Channel{} = channel, pid]) do
    state = %State{cache: :ets.new(:monitored, [:set]), channel: channel}
    members = get_members(state)
    :ok = join([pid | members], state)
    if [] == get_members(state) do
      {:stop, :normal}
    else
      Logger.debug(fn -> "Started #{__MODULE__} for #{inspect channel}" end)
      {:ok, state}
    end
  end

  @impl true
  def handle_call({:add, pid}, _from, %State{} = state) do
    join(pid, state)
    {:reply, :ok, state}
  end
  def handle_call({:remove, pid}, _from, %State{} = state) do
    if leave(pid, state) > 0 do
      {:reply, :ok, state}
    else
      {:stop, :normal, :ok, state}
    end
  end
  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _, _, pid, _}, %State{} = state) do
    if leave(pid, state) > 0 do
      {:noreply, state}
    else
      {:stop, :normal, state}
    end
  end
  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def terminate(:normal, %State{channel: name}) do
    :pg2.delete(name)
    Generator.stop_distributor(name)
    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect name}"
    end)
  end
  def terminate(reason, %State{channel: name} = _state) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect name} due to #{inspect reason}"
    end)
  end

  #################
  # General helpers

  @doc false
  @spec get_members(State.t()) :: list(pid())
  def get_members(state)

  def get_members(%State{channel: name}) do
    with members when is_list(members) <- :pg2.get_members(name) do
      members
    else
      {:error, {:no_such_group, ^name}} ->
        :pg2.create(name)
        []
    end
  end

  ################
  # Join functions

  @doc false
  @spec join(pid() | list(pid()), State.t()) :: :ok | {:error, term()}
  def join(pids, state)

  def join([], _) do
    :ok
  end
  def join([pid | pids], %State{} = state) do
    join(pid, state)
    join(pids, state)
  end
  def join(pid, %State{channel: name} = state) do
    with members when is_list(members) <- :pg2.get_members(name) do
      monitor(pid, state)
      if not (pid in members), do: :pg2.join(name, pid)
      :ok
    end
  end

  @doc false
  @spec monitor(pid(), State.t()) :: :ok | {:error, term()}
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
  @spec leave(pid(), State.t()) :: integer()
  def leave(pid, %State{channel: name} = state) do
    :pg2.leave(name, pid)
    demonitor(pid, state)
    length(:pg2.get_members(name))
  end

  @doc false
  @spec demonitor(pid(), State.t()) :: :ok
  def demonitor(pid, %State{cache: cache}) do
    with [{^pid, ref} | _] <- :ets.lookup(cache, pid) do
      :ets.delete(cache, pid)
      Process.demonitor(ref)
    end
    :ok
  end
end
