defmodule Yggdrasil.Subscriber.Adapter.Elixir do
  @moduledoc """
  Yggdrasil subscriber adapter for Elixir. The name of the channel can be any
  arbitrary term e.g:

  Subscription to channel:

  ```elixir
  iex(1)> alias Yggdrasil.Channel
  iex(2)> sub_channel = %Channel{
  ...(2)>   name: {:test, "elixir_channel"},
  ...(2)>   adapter: Yggdrasil.Subscriber.Adapter.Elixir
  ...(2)> }
  iex(3)> Yggdrasil.subscribe(sub_channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Channel{name: {:test, "elixir_channel"}, (...)}}
  ```

  Publishing message:

  ```elixir
  iex(5)> pub_channel = %Channel{
  ...(5)>   name: {:test, "elixir_channel"},
  ...(5)>   adapter: Yggdrasil.Publisher.Adapter.Elixir
  ...(5)> }
  iex(6)> Yggdrasil.publish(pub_channel, "message")
  :ok
  ```

  Subscriber receiving message:

  ```elixir
  iex(7)> flush()
  {:Y_EVENT, %Channel{name: {:test, "elixir_channel"}, (...)}, "message"}
  ```

  Instead of having `sub_channel` and `pub_channel`, the hibrid channel can be
  used. For the previous example we can do the following:

  ```elixir
  iex(1)> alias Yggdrasil.Channel
  iex(2)> channel = %Channel{name: {:test, "elixir_channel"}, adapter: :elixir}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Channel{name: {:test, "elixir_channel"}, (...)}}
  iex(5)> Yggdrasil.publish(channel, "message")
  :ok
  iex(6)> flush()
  {:Y_EVENT, %Channel{name: {:test, "elixir_channel"}, (...)}, "message"} 
  ```
  """
  use GenServer

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend

  defstruct [:publisher, :channel, :conn]
  alias __MODULE__, as: State

  #############################################################################
  # Client API.

  @doc """
  Starts a Elixir subscriber adapter in a `channel` with some subscriber
  `publisher` and optionally `GenServer` `options`.
  """
  def start_link(%Channel{} = channel, publisher, options \\ []) do
    state = %State{publisher: publisher, channel: channel}
    GenServer.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops the Elixir adapter with its `pid`.
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  #############################################################################
  # GenServer callback.

  @doc false
  def init(%State{channel: %Channel{name: name} = channel} = state) do
    conn = %Channel{channel | name: {:elixir, name}}
    Backend.subscribe(conn)
    Backend.connected(channel)
    {:ok, %State{state | conn: conn}}
  end

  @doc false
  def handle_info(
    {:Y_EVENT, _, message},
    %State{publisher: publisher, channel: %Channel{name: name}} = state
  ) do
    Publisher.notify(publisher, name, message)
    {:noreply, state}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  @doc false
  def terminate(_, %State{conn: conn}) do
    Backend.unsubscribe(conn)
    :ok
  end
end
