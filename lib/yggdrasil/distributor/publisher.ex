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
  Notifies synchronously of a new `message` to a `publisher`.
  """
  def notify(publisher, message) do
    GenServer.call(publisher, {:notify, message})
  end

  #############################################################################
  # GenServer callbacks.

  @doc false
  def init(%Channel{} = channel) do
    Logger.debug("Started publisher for #{inspect channel}")
    {:ok, channel}
  end

  @doc false
  def handle_call(
    {:notify, message},
    _from,
    %Channel{transformer: transformer_module} = channel
  ) do
    result =
      with {:ok, decoded} <- transformer_module.decode(channel, message),
           do: Backend.publish(channel, decoded)
    {:reply, result, channel}
  end
  def handle_call(_msg, _from, %Channel{} = channel) do
    {:noreply, channel}
  end
end
