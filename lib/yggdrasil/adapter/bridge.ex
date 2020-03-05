defmodule Yggdrasil.Adapter.Bridge do
  @moduledoc """
  Yggdrasil bridge adapter. The name of the channel is a valid remote
  Yggdrasil.Channel e.g:

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
  use Yggdrasil.Adapter, name: :bridge

  alias Yggdrasil.Channel
  alias Yggdrasil.Registry

  @doc """
  Splits channels in a `bridge` channel.
  """
  @spec split_channels(Channel.t()) ::
          {:ok, {Channel.t(), Channel.t()}} | {:error, term()}
  def split_channels(bridge)

  def split_channels(%Channel{name: remote} = bridge) do
    with {:ok, channel} <- get_remote_channel(remote) do
      name = :erlang.phash2(channel)

      stream = %Channel{
        bridge
        | name: {:"$yggdrasil_bridge", name},
          adapter: :elixir
      }

      {:ok, {stream, channel}}
    end
  end

  #########
  # Helpers

  # Gets remote `channel`.
  @spec get_remote_channel(Channel.t() | map() | keyword()) ::
          {:ok, Channel.t()} | {:error, term()}
  defp get_remote_channel(channel)

  defp get_remote_channel(%Channel{adapter: adapter} = channel) do
    with {:ok, node} <- Registry.get_adapter_node(adapter) do
      do_get_remote_channel(node, channel)
    end
  end

  defp get_remote_channel(channel) when is_map(channel) or is_list(channel) do
    Channel
    |> struct(channel)
    |> get_remote_channel()
  end

  # Gets remote full remote channel given a `node` and a `channel`.
  @spec do_get_remote_channel(node(), Channel.t()) ::
          {:ok, Channel.t()} | {:error, term()}
  defp do_get_remote_channel(node, channel)

  defp do_get_remote_channel(node, %Channel{} = channel) do
    case :rpc.call(node, Registry, :get_full_channel, [channel]) do
      {:ok, _} = result -> result
      {:badrpc, reason} -> {:error, reason}
      {:error, _} = error -> error
    end
  end
end
