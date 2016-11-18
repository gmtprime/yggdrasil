defmodule Yggdrasil.Distributor.Backend do
  @moduledoc """
  Distributor backend to subscribe, unsubscribe and publish messages. Uses
  `Phoenix.PubSub` for message distribution.

  Published messages comes in the form of `{:Y_EVENT, Channel.t(), term()}`.
  """
  alias Phoenix.PubSub
  alias Yggdrasil.Channel

  @pubsub Application.get_env(:yggdrasil, :pubsub_name, Yggdrasil.PubSub)

  @doc false
  def transform_name(%Channel{namespace: nil} = channel) do
    transform_name(%Channel{channel | namespace: Yggdrasil})
  end
  def transform_name(%Channel{name: name, namespace: namespace}) do
    {name, namespace} |> :erlang.phash2() |> Integer.to_string()
  end

  @doc """
  Subscribes to a `channel`.
  """
  @spec subscribe(Channel.t()) :: :ok | {:error, term()}
  def subscribe(%Channel{} = channel) do
    channel_name = transform_name(channel)
    PubSub.unsubscribe(@pubsub, channel_name)
    PubSub.subscribe(@pubsub, channel_name)
  end

  @doc """
  Unsubscribes from a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(%Channel{} = channel) do
    channel_name = transform_name(channel)
    PubSub.unsubscribe(@pubsub, channel_name)
  end

  @doc false
  def connected(%Channel{} = channel) do
    real_message = {:Y_CONNECTED, channel}
    channel_name = transform_name(channel)
    PubSub.broadcast(@pubsub, channel_name, real_message)
  end

  @doc false
  def connected(%Channel{} = channel, pid) do
    real_message = {:Y_CONNECTED, channel}
    send pid, real_message
    :ok
  end

  @doc """
  Publishes a `message` in a `channel`.
  """
  @spec publish(Channel.t(), term()) :: :ok | {:error, term()}
  def publish(%Channel{} = channel, message) do
    real_message = {:Y_EVENT, channel, message} 
    channel_name = transform_name(channel)
    PubSub.broadcast(@pubsub, channel_name, real_message)
  end
end
