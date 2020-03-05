defmodule Yggdrasil.Adapter.Bridge.Subscriber do
  @moduledoc """
  This module defines a bridge remote subscriber.
  """
  use GenServer

  require Logger

  alias Yggdrasil.Channel

  @doc false
  defstruct [:target, :pid, :channel]
  alias __MODULE__, as: State

  @doc """
  Starts a bridge remote subscriber.
  """
  @spec start_link(pid(), Channel.t(), Channel.t()) :: GenServer.on_start()
  @spec start_link(pid(), Channel.t(), Channel.t(), GenServer.options()) ::
          GenServer.on_start()
  def start_link(pid, target, channel, options \\ []) do
    state = %State{target: target, channel: channel, pid: pid}
    GenServer.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops a bridge remote subscriber.
  """
  @spec stop(GenServer.server()) :: :ok
  @spec stop(GenServer.server(), term()) :: :ok
  @spec stop(GenServer.server(), term(), non_neg_integer() | :infinity) :: :ok
  defdelegate stop(bridge, reason \\ :normal, timeout \\ :infinity),
    to: GenServer

  @impl GenServer
  def init(%State{pid: pid, channel: channel} = state) do
    Process.monitor(pid)

    case Yggdrasil.subscribe(channel) do
      :ok ->
        Logger.debug(fn ->
          "Started #{__MODULE__} for #{inspect(pid)} and #{inspect(channel)}"
        end)

        {:ok, state}

      {:error, reason} ->
        Logger.error(fn ->
          "Cannot start #{__MODULE__} due to #{inspect(reason)}"
        end)

        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_info({:Y_CONNECTED, _}, %State{target: target} = state) do
    Yggdrasil.publish(target, :Y_CONNECTED)
    {:noreply, state}
  end

  def handle_info({:Y_EVENT, _, message}, %State{target: target} = state) do
    Yggdrasil.publish(target, message)
    {:noreply, state}
  end

  def handle_info({:Y_DISCONNECTED, _}, %State{target: target} = state) do
    Yggdrasil.publish(target, :Y_DISCONNECTED)
    {:noreply, state}
  end

  def handle_info({:DOWN, _, _, _, _}, %State{} = state) do
    {:stop, :normal, state}
  end

  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(:normal, %State{pid: pid, channel: channel}) do
    Yggdrasil.unsubscribe(channel)

    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect(pid)} and #{inspect(channel)}"
    end)
  end

  def terminate(reason, %State{pid: pid, channel: channel}) do
    Yggdrasil.unsubscribe(channel)

    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect(pid)} and #{inspect(channel)}" <>
        " due to #{inspect(reason)}"
    end)
  end
end
