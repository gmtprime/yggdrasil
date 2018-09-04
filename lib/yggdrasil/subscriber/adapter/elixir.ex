defmodule Yggdrasil.Subscriber.Adapter.Elixir do
  @moduledoc """
  Yggdrasil subscriber adapter for Elixir. The name of the channel can be any
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
  use Yggdrasil.Subscriber.Adapter
  use GenServer

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Subscriber.Publisher
  alias Yggdrasil.Backend

  defstruct [:channel, :conn]
  alias __MODULE__, as: State

  ####################
  # GenServer callback

  @impl true
  def init(%{channel: %Channel{name: name} = channel} = arguments) do
    state = struct(State, arguments)
    conn = %Channel{channel | name: {:elixir, name}}
    Backend.subscribe(conn)
    Manager.connected(channel)
    Logger.debug(fn -> "Started #{__MODULE__} for #{inspect channel}" end)
    {:ok, %State{state | conn: conn}}
  end

  @impl true
  def handle_info(
    {:Y_EVENT, _, message},
    %State{channel: %Channel{} = channel} = state
  ) do
    Publisher.notify(channel, message)
    {:noreply, state}
  end
  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(:normal, %State{channel: channel, conn: conn}) do
    Backend.unsubscribe(conn)
    Manager.disconnected(channel)
    Logger.debug(fn -> "Stopped #{__MODULE__} for #{inspect channel}" end)
  end
  def terminate(reason, %State{channel: channel, conn: conn}) do
    Backend.unsubscribe(conn)
    Manager.disconnected(channel)
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect channel} due to #{inspect reason}"
    end)
  end
end
