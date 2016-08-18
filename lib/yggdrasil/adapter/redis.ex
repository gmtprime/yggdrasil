defmodule Yggdrasil.Adapter.Redis do
  @moduledoc """
  Yggdrasil adapter for Redis.
  """
  use GenServer
  use Yggdrasil.Adapter
  require Logger

  alias Yggdrasil.Adapter 
  alias Yggdrasil.Publisher

  ##
  # State for Redis adapter.
  defstruct [:publisher, :conn, :parent, :ready]
  alias __MODULE__, as: State

  ##
  # Gets Redis options from configuration.
  defp redis_options do
    Application.get_env(:yggdrasil, :redis, [host: "localhost"])
  end

  @doc false
  def is_connected?(adapter) do
    GenServer.call(adapter, :connected?)
  end

  @doc false
  def init(%Adapter{publisher: publisher, channel: channel}) do
    options = redis_options()
    {:ok, conn} = Redix.PubSub.start_link(options)
    state = %State{publisher: publisher, conn: conn, ready: false, parent: nil}
    :ok = Redix.PubSub.psubscribe(conn, channel, self())
    {:ok, state}
  end

  @doc false
  def handle_call(:connected?, from, %State{ready: false} = state) do
    pid = spawn_link fn ->
      result = receive do
        result -> result
      after
        5000 -> false
      end
      GenServer.reply(from, result)
    end
    {:noreply, %State{state | parent: pid}}
  end
  def handle_call(:connected?, _from, %State{ready: true} = state) do
    {:reply, true, state}
  end

  @doc false
  def handle_info(
    {:redix_pubsub, _, :psubscribed, %{pattern: channel}},
    %State{parent: pid} = state
  ) do
    if not is_nil(pid), do: send pid, true
    Logger.debug("Connected to Redis #{inspect [channel: channel]}")
    {:noreply, %State{state | parent: nil, ready: true}}
  end
  def handle_info(
    {:redix_pubsub, _, :pmessage, %{channel: channel, payload: message}},
    %State{publisher: publisher} = state
  ) do
    Publisher.sync_notify(publisher, channel, message)
    {:noreply, state}
  end
  def handle_info({:redix_pubsub, _, _, _}, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(_reason, %State{conn: conn}) do
    Redix.PubSub.stop(conn)
    :ok
  end
end
