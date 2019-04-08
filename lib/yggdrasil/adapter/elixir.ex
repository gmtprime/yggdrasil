defmodule Yggdrasil.Adapter.Elixir do
  @moduledoc """
  Yggdrasil adapter for Elixir. The name of the channel can be any arbitrary
  term e.g:

  First we subscribe to a channel:

  ```
  iex> channel = [name: "elixir_channel"]
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
  use Yggdrasil.Adapter, name: :elixir
end
