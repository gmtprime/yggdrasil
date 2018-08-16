defmodule Yggdrasil.Adapter.Elixir do
  @moduledoc """
  Yggdrasil adapter for Elixir. The name of the channel can be any arbitrary
  term e.g:

  Subscription to channel:

  ```
  iex(2)> channel = %Yggdrasil.Channel{name: "elixir_channel"}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: "elixir_channel", (...)}}
  ```

  Publishing message:

  ```
  iex(5)> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  Subscriber receiving message:

  ```
  iex(6)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: "elixir_channel", (...)}, "foo"}
  ```

  The subscriber can also unsubscribe from the channel:

  ```
  iex(7)> Yggdrasil.unsubscribe(channel)
  :ok
  iex(8)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{name: "elixir_channel", (...)}}
  ```
  """
  use Yggdrasil.Adapter, name: :elixir
end
