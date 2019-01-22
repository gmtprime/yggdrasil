defmodule Yggdrasil.Subscriber.Publisher do
  @moduledoc """
  A server to distribute the messages.
  """
  use GenServer

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Settings
  alias Yggdrasil.Transformer

  require Logger

  @registry Settings.yggdrasil_process_registry!()

  #############################################################################
  # Client API.

  @doc """
  Starts a server to distribute messages in a `channel`. Additionally can
  receive `GenServer` `options`.
  """
  @spec start_link(Channel.t()) :: GenServer.on_start()
  @spec start_link(Channel.t(), GenServer.options()) :: GenServer.on_start()
  def start_link(channel, options \\ [])

  def start_link(%Channel{} = channel, options) do
    GenServer.start_link(__MODULE__, channel, options)
  end

  @doc """
  Stops a `publisher`.
  """
  @spec stop(GenServer.name()) :: :ok
  def stop(publisher)

  def stop(publisher) do
    GenServer.stop(publisher)
  end

  @doc """
  Notifies synchronously of a new `message` coming from a `channel`.
  """
  @spec notify(
          channel :: Channel.t(),
          message :: term()
        ) :: :ok | {:error, term()}
  def notify(%Channel{name: name} = channel, message, metadata \\ nil) do
    publisher = {:via, @registry, {__MODULE__, channel}}
    notify(publisher, name, message, metadata)
  end

  @doc """
  Notifies synchronously of a new `message` coming from a `channel_name` to a
  `publisher` with some `metadata`.
  """
  @spec notify(
          publisher :: GenServer.name(),
          channel_name :: term(),
          message :: term(),
          metadata :: term()
        ) :: :ok | {:error, term()}
  def notify(publisher, channel_name, message, metadata) do
    GenServer.call(publisher, {:notify, channel_name, message, metadata})
  end

  #############################################################################
  # GenServer callbacks.

  @impl true
  def init(%Channel{} = channel) do
    Logger.debug(fn -> "Started #{__MODULE__} for #{inspect(channel)}" end)
    {:ok, channel}
  end

  @impl true
  def handle_call(
        {:notify, channel_name, message, metadata},
        _from,
        %Channel{} = channel
      ) do
    real_channel = %Channel{channel | name: channel_name}

    result =
      with {:ok, decoded} <- Transformer.decode(real_channel, message) do
        Backend.publish(real_channel, decoded, metadata)
      end

    {:reply, result, channel}
  end

  def handle_call(_msg, _from, %Channel{} = channel) do
    {:noreply, channel}
  end

  @impl true
  def terminate(:normal, %Channel{} = channel) do
    Logger.debug(fn -> "Stopped #{__MODULE__} for #{inspect(channel)}" end)
  end

  def terminate(reason, %Channel{} = channel) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect(channel)} due to #{inspect(reason)}"
    end)
  end
end
