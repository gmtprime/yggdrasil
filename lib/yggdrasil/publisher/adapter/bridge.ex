defmodule Yggdrasil.Publisher.Adapter.Bridge do
  @moduledoc """
  Yggdrasil bridge publisher adapter. The name of the channel can be any
  arbitrary term e.g:

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
  use Yggdrasil.Publisher.Adapter
  use GenServer

  alias Yggdrasil.Adapter.Bridge
  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Adapter
  alias Yggdrasil.Registry
  alias Yggdrasil.Transformer

  @doc """
  Publishes a `message` in a `channel` using a `publisher` with some `options`.
  """
  @impl Adapter
  def publish(publisher, channel, message, options \\ [])

  def publish(publisher, %Channel{} = channel, message, options) do
    GenServer.call(publisher, {:publish, channel, message, options})
  end

  ####################
  # GenServer callback

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:publish, %Channel{} = bridge, message, options}, _, _) do
    result = handle_publish(bridge, message, options)
    {:reply, result, nil}
  end

  ########
  # Helper

  # Handles a `message` publishing with some `options` in a `bridge` channel.
  @spec handle_publish(Channel.t(), term(), term()) :: :ok | {:error, term()}
  defp handle_publish(bridge, message, options)

  defp handle_publish(%Channel{} = bridge, message, options) do
    with {:ok, {stream, channel}} <- Bridge.split_channels(bridge),
         {:ok, encoded} <- Transformer.encode(stream, message) do
      remote_publish(channel, encoded, options)
    end
  end

  # Publishes message to a remote channel.
  @spec remote_publish(Channel.t(), term(), term()) :: :ok | {:error, term()}
  defp remote_publish(channel, message, options)

  defp remote_publish(%Channel{adapter: adapter} = channel, message, options) do
    with {:ok, node} <- Registry.get_adapter_node(adapter) do
      do_remote_publish(node, channel, message, options)
    end
  end

  # Publishes a message in a node.
  @spec do_remote_publish(node(), Channel.t(), term(), term()) ::
          :ok | {:error, term()}
  defp do_remote_publish(node, channel, message, options)

  defp do_remote_publish(node, %Channel{} = channel, message, options) do
    args = [channel, message, options]

    case :rpc.call(node, Yggdrasil, :publish, args) do
      :ok -> :ok
      {:badrpc, reason} -> {:error, reason}
      {:error, _} = error -> error
    end
  end
end
