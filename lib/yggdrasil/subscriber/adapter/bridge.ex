defmodule Yggdrasil.Subscriber.Adapter.Bridge do
  @moduledoc """
  Yggdrasil bridge subscriber adapter. The name of the channel is a valid
  remote `Yggdrasil.Channel` e.g:

  First we subscribe to a channel:

  ```
  iex> channel = [name: [name: "remote_channel"], adapter: :bridge]
  iex> Yggdrasil.subscribe(channel)
  :ok
  iex> flush()
  {:Y_CONNECTED, ...}
  ```

  Once connected, you can publish a message in that channel:

  ```
  iex> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  And the subscriber should receive the message:

  ```
  iex> flush()
  {:Y_EVENT, ..., "foo"}
  ```

  Additionally, the subscriber can also unsubscribe from the channel:

  ```
  iex> Yggdrasil.unsubscribe(channel)
  :ok
  iex> flush()
  {:Y_DISCONNECTED, ...}
  ```
  """
  use Yggdrasil.Subscriber.Adapter
  use GenServer

  require Logger

  alias Yggdrasil.Adapter.Bridge
  alias Yggdrasil.Adapter.Bridge.Generator, as: BridgeGen
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Subscriber.Publisher

  @doc false
  defstruct [:node, :bridge, :local, :remote, :state]
  alias __MODULE__, as: State

  @warm_up :warm_up
  @connected :connected
  @disconnected :disconnected

  @impl GenServer
  def init(%{channel: %Channel{} = bridge}) do
    Process.flag(:trap_exit, true)

    with {:ok, {local, remote}} <- Bridge.split_channels(bridge),
         {:ok, node} <- get_channel_node(remote) do
      state = %State{
        node: node,
        bridge: bridge,
        local: local,
        remote: remote,
        state: @warm_up
      }

      {:ok, state, {:continue, :warm_up}}
    else
      {:error, reason} ->
        Logger.error(fn ->
          "Cannot start #{__MODULE__} due to #{inspect(reason)}"
        end)

        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_continue(:warm_up, %State{local: local} = state) do
    :ok = Yggdrasil.subscribe(local)
    {:noreply, state}
  end

  def handle_continue(
        :subscribe,
        %State{node: node, local: local, remote: remote} = state
      ) do
    case handle_subscription(node, local, remote) do
      :ok -> {:noreply, state}
      {:error, _} = error -> {:stop, error, state}
    end
  end

  @impl GenServer
  def handle_info({:Y_CONNECTED, _}, %State{state: @warm_up} = state) do
    new_state = %State{state | state: @disconnected}
    {:noreply, new_state, {:continue, :subscribe}}
  end

  def handle_info(
        {:Y_EVENT, _, :Y_CONNECTED},
        %State{bridge: bridge, state: @disconnected} = state
      ) do
    Manager.connected(bridge)
    new_state = %State{state | state: @connected}
    {:noreply, new_state}
  end

  def handle_info(
        {:Y_EVENT, _, :Y_DISCONNECTED},
        %State{bridge: bridge, state: @connected} = state
      ) do
    Manager.disconnected(bridge)
    new_state = %State{state | state: @disconnected}
    {:noreply, new_state}
  end

  def handle_info({:Y_EVENT, _, message}, %State{bridge: bridge} = state) do
    Publisher.notify(bridge, message)
    {:noreply, state}
  end

  def handle_info(
        {:DOWN, _, _, _, _},
        %State{bridge: bridge, state: @connected} = state
      ) do
    Manager.disconnected(bridge)
    new_state = %State{state | state: @disconnected}
    {:noreply, new_state, {:continue, :subscribe}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(:normal, %State{bridge: bridge, state: @connected}) do
    Manager.disconnected(bridge)
    Logger.debug(fn -> "Stopped #{__MODULE__} for #{inspect(bridge)}" end)
  end

  def terminate(:normal, %State{bridge: bridge}) do
    Logger.debug(fn -> "Stopped #{__MODULE__} for #{inspect(bridge)}" end)
  end

  def terminate(reason, %State{bridge: bridge, state: @connected}) do
    Manager.disconnected(bridge)

    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect(bridge)} due to #{inspect(reason)}"
    end)
  end

  def terminate(reason, %State{bridge: bridge}) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect(bridge)} due to #{inspect(reason)}"
    end)
  end

  #########
  # Helpers

  # Gets channel node.
  @spec get_channel_node(Channel.t()) :: {:ok, node()} | {:error, term()}
  defp get_channel_node(channel)

  defp get_channel_node(%Channel{adapter: adapter}) do
    Registry.get_adapter_node(adapter)
  end

  # Handles subscription.
  @spec handle_subscription(node, Channel.t(), Channel.t()) ::
          :ok | {:error, term()}
  defp handle_subscription(node, local, remote)

  defp handle_subscription(node, %Channel{} = local, %Channel{} = remote) do
    with {:ok, pid} <- run_remote_subscriber(node, local, remote) do
      Process.monitor(pid)
      :ok
    end
  end

  # Runs a remote subscriber.
  @spec run_remote_subscriber(node(), Channel.t(), Channel.t()) ::
          {:ok, pid()} | {:error, term()}
  defp run_remote_subscriber(node, local, remote)

  defp run_remote_subscriber(node, %Channel{} = local, %Channel{} = remote) do
    args = [self(), local, remote]

    case :rpc.call(node, BridgeGen, :start_bridge, args) do
      {:ok, _} = ok -> ok
      {:badrpc, reason} -> {:error, reason}
      {:error, _} = error -> error
    end
  end
end
