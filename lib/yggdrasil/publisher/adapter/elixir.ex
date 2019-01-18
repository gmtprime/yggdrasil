defmodule Yggdrasil.Publisher.Adapter.Elixir do
  @moduledoc """
  Yggdrasil publisher adapter for Elixir. The name of the channel can be any
  arbitrary term e.g:

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
  use Yggdrasil.Publisher.Adapter
  use GenServer

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Transformer

  ####################
  # GenServer callback

  @impl true
  def init(_) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:publish, %Channel{name: name} = channel, message}, _, _) do
    stream = %Channel{channel | name: {:elixir, name}}

    result =
      with {:ok, encoded} <- Transformer.encode(stream, message) do
        Backend.publish(stream, encoded)
      end

    {:reply, result, nil}
  end

  def handle_call(_, _, _) do
    {:noreply, nil}
  end
end
