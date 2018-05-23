defmodule Yggdrasil.Distributor.Publisher do
  @moduledoc """
  A server to distribute the messages.
  """
  use GenServer

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend

  require Logger

  #############################################################################
  # Client API.

  @doc """
  Starts a server to distribute messages in a `channel`. Additionally can
  receive `GenServer` `options`.
  """
  def start_link(%Channel{} = channel, options \\ []) do
    GenServer.start_link(__MODULE__, channel, options)
  end

  @doc """
  Stops a `publisher`.
  """
  def stop(publisher) do
    GenServer.stop(publisher)
  end

  @doc """
  Notifies synchronously of a new `message` coming from a `channel_name` to a
  `publisher`.
  """
  def notify(publisher, channel_name, message) do
    GenServer.call(publisher, {:notify, channel_name, message})
  end

  #############################################################################
  # GenServer callbacks.

  @doc false
  def init(%Channel{} = channel) do
    Logger.debug(fn -> "Started #{__MODULE__} for #{inspect channel}" end)
    {:ok, channel}
  end

  @doc false
  def handle_call(
    {:notify, channel_name, message},
    _from,
    %Channel{transformer: transformer_module} = channel
  ) do
    real_channel = %Channel{channel | name: channel_name}
    result =
      with {:ok, decoded} <- transformer_module.decode(real_channel, message),
           do: Backend.publish(channel, decoded)
    {:reply, result, channel}
  end
  def handle_call(_msg, _from, %Channel{} = channel) do
    {:noreply, channel}
  end

  @doc false
  def terminate(:normal, %Channel{} = channel) do
    Logger.debug(fn -> "Stopped #{__MODULE__} for #{inspect channel}" end)
  end
  def terminate(reason, %Channel{} = channel) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect channel} due to #{inspect reason}"
    end)
  end
end
