defmodule Yggdrasil.Distributor.Adapter.Elixir do
  @moduledoc """
  Yggdrasil distributor adapter for Elixir.
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
  Starts a Elixir distributor adapter in a `channel` with some distributor
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
    %State{publisher: publisher} = state
  ) do
    Publisher.notify(publisher, message)
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
