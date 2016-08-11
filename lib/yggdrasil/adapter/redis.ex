defmodule Yggdrasil.Adapter.Redis do
  @moduledoc """
  Yggdrasil adapter for Redis.
  """
  use GenServer
  use Yggdrasil.Adapter 

  alias Yggdrasil.Adapter 
  alias Yggdrasil.Publisher

  ##
  # State for Redis adapter.
  defstruct [:publisher, :conn]
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
    state = %State{publisher: publisher, conn: conn}
    :ok = Redix.PubSub.psubscribe(conn, channel, self())
    {:ok, state}
  end

  @doc false
  def handle_call(:connected?, _from, %State{} = state) do
    {:reply, true, state}
  end

  @doc false
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
