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
  use GenServer

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend

  defstruct [:publisher, :channel, :conn]
  alias __MODULE__, as: State

  ############
  # Client API

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

  ####################
  # GenServer callback

  @doc false
  def init(%State{channel: %Channel{name: name} = channel} = state) do
    conn = %Channel{channel | name: {:elixir, name}}
    Backend.subscribe(conn)
    Backend.connected(channel)
    Logger.debug(fn -> "Started #{__MODULE__} for #{inspect channel}" end)
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
  def terminate(:normal, %State{channel: channel, conn: conn}) do
    Backend.unsubscribe(conn)
    Backend.disconnected(channel)
    Logger.debug(fn -> "Stopped #{__MODULE__} for #{inspect channel}" end)
  end
  def terminate(reason, %State{channel: channel, conn: conn}) do
    Backend.unsubscribe(conn)
    Backend.disconnected(channel)
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect channel} due to #{inspect reason}"
    end)
  end
end
