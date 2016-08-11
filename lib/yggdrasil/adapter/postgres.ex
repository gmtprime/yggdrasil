defmodule Yggdrasil.Adapter.Postgres do
  @moduledoc """
  Yggdrasil adapter for Postgres.
  """
  use GenServer
  use Yggdrasil.Adapter

  alias Yggdrasil.Adapter 
  alias Yggdrasil.Publisher

  ##
  # State for RabbitMQ adapter.
  defstruct [:publisher, :channel, :conn, :ref]
  alias __MODULE__, as: State

  ##
  # Gets Redis options from configuration.
  defp postgres_options do
    Application.get_env(:yggdrasil, :postgres, [])
  end

  @doc false
  def is_connected?(adapter) do
    GenServer.call(adapter, :connected?)
  end

  @doc false
  def init(%Adapter{publisher: publisher, channel: channel}) do
    options = postgres_options()
    {:ok, conn} = Postgrex.Notifications.start_link(options)
    {:ok, ref} = Postgrex.Notifications.listen(conn, channel)
    state = %State{publisher: publisher,
                   channel: channel,
                   conn: conn,
                   ref: ref}
    {:ok, state}
  end

  @doc false
  def handle_call(:connected?, _from, %State{} = state) do
    {:reply, true, state}
  end

  @doc false
  def handle_info(
    {:notification, _, _, _, message},
    %State{publisher: publisher, channel: channel} = state
  ) do
    Publisher.sync_notify(publisher, channel, message)
    {:noreply, state}
  end
  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(_reason, %State{conn: conn, ref: ref}) do
    Postgrex.Notifications.unlisten(conn, ref)
    GenServer.stop(conn)
    :ok
  end
end
