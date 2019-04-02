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
end
