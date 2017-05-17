defmodule Yggdrasil.Publisher.Adapter.Postgres do
  @moduledoc """
  A server for Postgres publishing.

  The name of a channel is a string.
  """
  use Connection

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Adapter.Postgres

  defstruct [:conn, :namespace]
  alias __MODULE__, as: State

  #############################################################################
  # Client API.

  @doc """
  Starts a Postgres publisher with a `namespace`. Additianally you can add
  `GenServer` `options`.
  """
  def start_link(namespace, options \\ []) do
    Connection.start_link(__MODULE__, namespace, options)
  end

  @doc """
  Stops a Postgres `publisher`.
  """
  def stop(publisher) do
    GenServer.stop(publisher)
  end

  @doc """
  Publishes a `message` in a `channel` using a `publisher`.
  """
  def publish(publisher, %Channel{} = channel, message) do
    Connection.call(publisher, {:publish, channel, message})
  end

  #############################################################################
  # GenServer callback.

  @doc false
  def init(namespace) do
    Process.flag(:trap_exit, true)
    state = %State{namespace: namespace}
    {:connect, :init, state}
  end

  @doc false
  def connect(_info, %State{namespace: namespace} = state) do
    options = Postgres.postgres_options(%Channel{namespace: namespace})
    {:ok, conn} = Postgrex.start_link(options)
    {:ok, %State{state | conn: conn}}
  end

  @doc false
  def disconnect(_info, %State{conn: nil} = state) do
    {:backoff, 5000, state}
  end
  def disconnect(info, %State{conn: conn} = state) do
    GenServer.stop(conn)
    disconnect(info, %State{state | conn: nil})
  end

  @doc false
  def handle_call(
    {:publish, _, _},
    _from,
    %State{conn: nil} = state
  ) do
    {:reply, {:error, "Disconnected"}, state}
  end
  def handle_call(
    {:publish, %Channel{name: name, transformer: encoder} = channel, message},
    _from,
    %State{conn: conn} = state
  ) do
    result =
      with {:ok, encoded} <- encoder.encode(channel, message),
           {:ok, _} <- Postgrex.query(conn, "NOTIFY #{name}, '#{encoded}'", []),
           do: :ok
    {:reply, result, state}
  end
  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def handle_info({:DOWN, _, :process, _pid, _reason}, %State{} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :down, new_state}
  end
  def handle_info({:EXIT, _, _}, %State{} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :exit, new_state}
  end

  @doc false
  def terminate(reason, %State{conn: nil} = state) do
    terminated(reason, state)
  end
  def terminate(reason, %State{conn: conn} = state) do
    GenServer.stop(conn)
    terminate(reason, %State{state | conn: nil})
  end

  defp terminated(reason, %State{} = _state) do
    metadata = [error: reason]
    Logger.debug("Terminated Postgres connection #{inspect metadata}")
    :ok
  end
end
