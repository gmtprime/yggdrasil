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

  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Transformer

  @doc """
  Publishes a `message` in a `channel` using a `publisher` with some `options`.
  """
  @spec publish(GenServer.server(), Channel.t(), term()) ::
          :ok | {:error, term()}
  @spec publish(GenServer.server(), Channel.t(), term(), Keyword.t()) ::
          :ok | {:error, term()}
  @impl true
  def publish(publisher, channel, message, options \\ [])

  def publish(publisher, %Channel{} = channel, message, options) do
    GenServer.call(publisher, {:publish, channel, message, options})
  end

  ####################
  # GenServer callback

  @impl GenServer
  def init(_), do: {:ok, nil}

  @impl GenServer
  def handle_call({:publish, %Channel{name: chan} = bridge, msg, opts}, _, _) do
    result =
      with {:ok, channel} <- get_remote_channel(chan),
           name = :erlang.phash2(channel),
           stream = %Channel{bridge | name: {:"$yggdrasil_bridge", name}},
           {:ok, encoded} <- Transformer.encode(stream, msg) do
        remote_publish(channel, encoded, opts)
      end

    {:reply, result, nil}
  end

  ########
  # Helper

  # Channel name.
  @spec get_remote_channel(term()) :: {:ok, integer()}
  defp get_remote_channel(channel)

  defp get_remote_channel(channel) do
    %Channel{adapter: adapter} = channel = struct(Channel, channel)
    with {:ok, node} <- Registry.get_adapter_node(adapter),
         {:ok, channel} <-
           :rpc.call(node, Registry, :get_full_channel, [channel]) do
      {:ok, channel}
    else
      {:badrpc, reason} ->
        {:error, reason}

      {:error, _} = error ->
        error
    end
  end

  # Publish message to a remote channel.
  @spec remote_publish(Channel.t(), term(), term()) :: :ok | {:error, term()}
  defp remote_publish(channel, message, options)

  defp remote_publish(%Channel{adapter: adapter} = channel, message, options) do
    with {:ok, node} <- Registry.get_adapter_node(adapter),
         args = [channel, message, options],
         :ok <- :rpc.call(node, Yggdrasil, :publish, args) do
      :ok
    else
      {:badrpc, reason} ->
        {:error, reason}

      {:error, _} = error ->
        error
    end
  end
end
