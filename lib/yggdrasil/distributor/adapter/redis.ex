defmodule Yggdrasil.Distributor.Adapter.Redis do
  @moduledoc """
  Yggdrasil distributor adapter for Redis.
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
  Starts a Redis distributor adapter in a `channel` with some distributor
  `publisher` and optionally `GenServer` `options`.
  """
  def start_link(%Channel{} = channel, publisher, options \\ []) do
    state = %State{publisher: publisher, channel: channel}
    GenServer.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops the Redis adapter with its `pid`.
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  #############################################################################
  # GenServer callbacks.

  @doc false
  def init(%State{channel: %Channel{name: name} = channel} = state) do
    options = redis_options(channel)
    {:ok, conn} = Redix.PubSub.start_link(options)
    state = %State{state | conn: conn}
    :ok = Redix.PubSub.psubscribe(conn, name, self())
    {:ok, state}
  end

  @doc false
  def handle_info(
    {:redix_pubsub, _, :psubscribed, %{pattern: _}},
    %State{channel: %Channel{name: name} = channel} = state
  ) do
    Logger.debug("Connected to Redis #{inspect [channel: name]}")
    Backend.connected(channel)
    {:noreply, state}
  end
  def handle_info(
    {:redix_pubsub, _, :pmessage, %{channel: channel_name, payload: message}},
    %State{publisher: publisher} = state
  ) do
    Publisher.notify(publisher, channel_name, message)
    {:noreply, state}
  end
  def handle_info({:redix_pubsub, _, _, _}, %State{} = state) do
    {:noreply, state}
  end
  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(_reason, %State{conn: conn}) do
    Redix.PubSub.stop(conn)
    :ok
  end

  #############################################################################
  # Helpers.

  @doc false
  def redis_options(%Channel{namespace: Yggdrasil}) do
    Application.get_env(:yggdrasil, :redis, [host: "localhost"])
  end
  def redis_options(%Channel{namespace: namespace}) do
    default = [redis: [host: "localhost"]]
    result = Application.get_env(:yggdrasil, namespace, default)
    Keyword.get(result, :redis, [host: "localhost"])
  end
end
