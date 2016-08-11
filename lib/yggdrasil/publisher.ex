defmodule Yggdrasil.Publisher do
  @moduledoc """
  A publisher server. Decodes the message comming from a connection and sends
  it to a channel.
  """
  use YProcess, backend: Yggdrasil.Backend

  alias Yggdrasil.Channel

  require Logger

  ###################
  # Client functions.

  @doc """
  Starts a publisher with a `channel` (`Yggdrasil.Channel`). This `channel`
  contains the decoder module, the channel where it'll write
  the decoded messages. Also it is possible to provide a list of GenServer
  `options`.
  """
  def start_link(%Channel{} = channel, options \\ []) do
    YProcess.start_link(__MODULE__, channel, options)
  end

  @doc """
  Stops a `publisher` with a `reason`. By default `reason` is `:normal`.
  """
  def stop(publisher, reason \\ :normal) do
    YProcess.stop(publisher, reason)
  end

  @doc """
  Notifies synchronously the `publisher` of a `message` in a `channel`.
  """
  def sync_notify(publisher, channel, message) do
    YProcess.call(publisher, {:sync_notify, channel, message})
  end

  @doc """
  Notifies asynchronously the `publisher` of a `message` in a `channel`.
  """
  def async_notify(publisher, channel, message) do
    YProcess.cast(publisher, {:async_notify, channel, message})
  end

  #####################
  # YProcess callbacks.

  @doc false
  def init(%Channel{channel: channel} = state) do
    Logger.debug("Started publisher for #{inspect state}.")
    {:create, [channel], state}
  end

  @doc false
  def handle_call(
    {:sync_notify, channel, message},
    _from,
    %Channel{decoder: decoder, channel: real_channel} = state
  ) do
    decoded = decoder.decode(channel, message)
    {:remit, [real_channel], decoded, :ok, state}
  end
  def handle_call(_, _from, %Channel{} = state) do
    {:noreply, state}
  end

  @doc false
  def handle_cast(
    {:async_notify, channel, message},
    %Channel{decoder: decoder, channel: real_channel} = state
  ) do
    decoded = decoder.decode(channel, message)
    {:emit, [real_channel], decoded, state}
  end
  def handle_cast(_, %Channel{} = state) do
    {:noreply, state}
  end
end
