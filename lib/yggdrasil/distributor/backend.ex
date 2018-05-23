defmodule Yggdrasil.Distributor.Backend do
  @moduledoc """
  Distributor backend to subscribe, unsubscribe and publish messages. Uses
  `Phoenix.PubSub` for message distribution.

  This module contains helper functions used by the adapters to broadcast their
  messages. The possible messages are:

    - `{:Y_CONNECTED, Channel.()}`: When a subscriber connects to a channel
    successfully. See `connected/2` function.
    - `{:Y_DISCONNECTED, Channel.()}`; When a subscriber disconnects from
    a channel successfully. See `disconnected/2` function.
    - `{:Y_EVENT, Channel.t(), message()} when message: term()`: When a
    subscriber gets a new messages from the adapter. See `publish/2` function.
  """
  alias Phoenix.PubSub
  alias Yggdrasil.Channel
  alias Yggdrasil.Settings
  alias Yggdrasil.Distributor.Manager

  @doc false
  @spec transform_name(Channel.t()) :: binary()
  def transform_name(%Channel{} = channel) do
    channel
    |> :erlang.phash2()
    |> Integer.to_string()
  end

  @doc """
  Subscribes to a `channel`.
  """
  @spec subscribe(Channel.t()) :: :ok | {:error, term()}
  def subscribe(channel)

  def subscribe(%Channel{} = channel) do
    if not Manager.subscribed?(channel) do
      pubsub = Settings.pubsub_name()
      channel_name = transform_name(channel)
      PubSub.subscribe(pubsub, channel_name)
    else
      :ok
    end
  end

  @doc """
  Unsubscribes from a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(channel)

  def unsubscribe(%Channel{} = channel) do
    if Manager.subscribed?(channel) do
      pubsub = Settings.pubsub_name()
      channel_name = transform_name(channel)
      PubSub.unsubscribe(pubsub, channel_name)
      disconnected(channel, self())
    else
      :ok
    end
  end

  @doc """
  Sends a `{:Y_CONNECTED, Channel.t()}` message to all the subscribers of the
  `channel` or optionally to a single `pìd`.
  """
  @spec connected(Channel.t()) :: :ok
  @spec connected(Channel.t(), pid()) :: :ok
  def connected(channel, pid \\ nil)

  def connected(%Channel{} = channel, nil) do
    pubsub = Settings.pubsub_name()
    real_message = {:Y_CONNECTED, channel}
    channel_name = transform_name(channel)
    PubSub.broadcast(pubsub, channel_name, real_message)
  end
  def connected(%Channel{} = channel, pid) do
    real_message = {:Y_CONNECTED, channel}
    send pid, real_message
    :ok
  end

  @doc """
  Sends a `{:Y_DISCONNECTED, Channel.t()}` message to all the subscribers of
  the `channel` or optionally to a single `pìd`.
  """
  @spec disconnected(Channel.t()) :: :ok
  @spec disconnected(Channel.t(), pid()) :: :ok
  def disconnected(channel, pid \\ nil)

  def disconnected(%Channel{} = channel, nil) do
    pubsub = Settings.pubsub_name()
    real_message = {:Y_DISCONNECTED, channel}
    channel_name = transform_name(channel)
    PubSub.broadcast(pubsub, channel_name, real_message)
  end
  def disconnected(%Channel{} = channel, pid) do
    real_message = {:Y_DISCONNECTED, channel}
    send pid, real_message
    :ok
  end

  @doc """
  Publishes a `message` in a `channel`.
  """
  @spec publish(Channel.t(), term()) :: :ok | {:error, term()}
  def publish(channel, message)

  def publish(%Channel{} = channel, message) do
    pubsub = Settings.pubsub_name()
    real_message = {:Y_EVENT, channel, message}
    channel_name = transform_name(channel)
    PubSub.broadcast(pubsub, channel_name, real_message)
  end
end
