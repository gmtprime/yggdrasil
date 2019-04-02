defmodule Yggdrasil.Publisher.Adapter.Elixir do
  @moduledoc """
  Yggdrasil publisher adapter for Elixir. The name of the channel can be any
  arbitrary term e.g:

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
  use Yggdrasil.Publisher.Adapter
  use GenServer

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Transformer

  ####################
  # GenServer callback

  @impl GenServer
  def init(_), do: {:ok, nil}

  @impl GenServer
  def handle_call({:publish, %Channel{name: name} = channel, message}, _, _) do
    stream = %Channel{channel | name: {:"$yggdrasil_elixir", name}}

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
