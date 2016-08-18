defmodule Yggdrasil.Adapter.Postgres do
  @moduledoc """
  Yggdrasil adapter for Postgres.
  """
  use Connection
  use Yggdrasil.Adapter, module: Connection
  require Logger

  alias Yggdrasil.Adapter 
  alias Yggdrasil.Publisher

  ##
  # State for RabbitMQ adapter.
  defstruct [:publisher, :channel, :conn, :ref, :parent]
  alias __MODULE__, as: State

  ##
  # Gets Redis options from configuration.
  defp postgres_options do
    Application.get_env(:yggdrasil, :postgres, [])
  end

  @doc false
  def is_connected?(adapter) do
    Connection.call(adapter, :connected?)
  end

  @doc false
  def init(%Adapter{publisher: publisher, channel: channel}) do
    Process.flag(:trap_exit, true)
    state = %State{publisher: publisher, channel: channel}
    {:connect, :init, state}
  end

  @doc false
  def connect(_info, %State{channel: channel} = state) do
    options = postgres_options()
    {:ok, conn} = Postgrex.Notifications.start_link(options)
    try do
      Postgrex.Notifications.listen(conn, channel)
    catch
      _, reason ->
        backoff(reason, state)
    else
      {:ok, ref} ->
        connected(conn, ref, state)
      error ->
        backoff(error, state)
    end
  end

  ##
  # Backoff.
  defp backoff(error, %State{channel: channel, parent: nil} = state) do
    metadata = [channel: channel, error: error]
    Logger.error("Cannot connect to Postgres #{inspect metadata}")
    {:backoff, 5000, state}
  end
  defp backoff(error, %State{parent: pid} = state) do
    send pid, false
    backoff(error, %State{state | parent: nil})
  end

  ##
  # Connected.
  defp connected(conn, ref, %State{channel: channel, parent: nil} = state) do
    Process.monitor(conn)
    metadata = [channel: channel]
    Logger.debug("Connected to Postgres #{inspect metadata}")
    new_state = %State{state | conn: conn, ref: ref}
    {:ok, new_state}
  end
  defp connected(conn, ref, %State{parent: pid} = state) do
    send pid, true
    connected(conn, ref, %State{state | parent: nil})
  end

  @doc false
  def disconnect(_info, %State{ref: nil, conn: nil} = state) do
    disconnected(state)
  end
  def disconnect(info, %State{conn: conn, ref: ref} = state) do
    Postgrex.Notifications.unlisten(conn, ref)
    GenServer.stop(conn)
    disconnect(info, %State{state | conn: nil, ref: nil})
  end

  ##
  # Disconnected.
  defp disconnected(%State{channel: channel} = state) do
    metadata = [channel: channel]
    Logger.debug("Disconnected from Postgres #{inspect metadata}")
    {:backoff, 5000, state}
  end

  @doc false
  def handle_call(:connected?, from, %State{conn: nil} = state) do
    pid = spawn_link fn ->
      result = receive do
        result -> result
      after
        5000 -> false
      end
      Connection.reply(from, result)
    end
    {:noreply, %State{state | parent: pid}}
  end
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
  def handle_info({:DOWN, _, :process, _, _}, %State{} = state) do
    new_state = %State{state | conn: nil, ref: nil}
    {:disconnect, :down, new_state}
  end
  def handle_info({:EXIT, _, _}, %State{} = state) do
    new_state = %State{state | conn: nil, ref: nil}
    {:disconnect, :exit, new_state}
  end
  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(reason, %State{conn: nil, ref: nil} = state) do
    terminated(reason, state)
  end
  def terminate(reason, %State{conn: conn, ref: ref} = state) do
    Postgrex.Notifications.unlisten(conn, ref)
    GenServer.stop(conn)
    terminate(reason, %State{state | conn: nil, ref: nil})
  end

  ##
  # Terminated.
  defp terminated(reason, %State{channel: channel}) do
    metadata = [channel: channel, reason: reason]
    Logger.debug("Terminated Postgres connection #{inspect metadata}")
    :ok
  end
end
