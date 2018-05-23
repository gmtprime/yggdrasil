defmodule Yggdrasil.Subscriber.Adapter.Postgres do
  @moduledoc """
  Yggdrasil subscriber adapter for Postgres. The name of the channel must be a
  binary e.g:

  Subscription to channel:

  ```
  iex(2)> channel = %Yggdrasil.Channel{name: "pg_channel", adapter: :postgres}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: "pg_channel", (...)}}
  ```

  Publishing message:

  ```
  iex(5)> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  Subscriber receiving message:

  ```
  iex(6)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: "pg_channel", (...)}, "foo"}
  ```

  The subscriber can also unsubscribe from the channel:

  ```
  iex(7)> Yggdrasil.unsubscribe(channel)
  :ok
  iex(8)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{name: "pg_channel", (...)}}
  ```
  """
  use Connection

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Settings

  defstruct [:publisher, :channel, :conn, :ref]
  alias __MODULE__, as: State

  ############
  # Client API

  @doc """
  Starts a Postgres distributor adapter in a `channel` with some distributor
  `publisher` and optionally `GenServer` `options`.
  """
  def start_link(%Channel{} = channel, publisher, options \\ []) do
    state = %State{publisher: publisher, channel: channel}
    Connection.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops the Postgres adapter with its `pid`.
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  ######################
  # Connection callbacks

  @doc false
  def init(%State{channel: %Channel{} = channel} = state) do
    Process.flag(:trap_exit, true)
    Logger.debug(fn -> "Started #{__MODULE__} for #{inspect channel}" end)
    {:connect, :init, state}
  end

  @doc false
  def connect(
    _info,
    %State{channel: %Channel{name: name} = channel} = state
  ) do
    options = postgres_options(channel)
    {:ok, conn} = Postgrex.Notifications.start_link(options)
    try do
      Postgrex.Notifications.listen(conn, name)
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
  defp backoff(error, %State{channel: %Channel{} = channel} = state) do
    Logger.warn(fn ->
      "#{__MODULE__} cannot connect to Postgres #{inspect channel}" <>
      "due to #{inspect error}"
    end)
    {:backoff, 5000, state}
  end

  ##
  # Connected.
  defp connected(conn, ref, %State{channel: %Channel{} = channel} = state) do
    Process.monitor(conn)
    Logger.debug(fn ->
      "#{__MODULE__} connected to Postgres #{inspect channel}"
    end)
    new_state = %State{state | conn: conn, ref: ref}
    Backend.connected(channel)
    {:ok, new_state}
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
  defp disconnected(%State{channel: %Channel{} = channel} = state) do
    Logger.debug(fn ->
      "#{__MODULE__} disconnected from Postgres #{inspect channel}"
    end)
    Backend.disconnected(channel)
    {:backoff, 5000, state}
  end

  @doc false
  def handle_info(
    {:notification, _, _, channel, message},
    %State{publisher: publisher} = state
  ) do
    Publisher.notify(publisher, channel, message)
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
  def terminate(
    reason,
    %State{channel: channel, conn: conn, ref: ref} = state
  ) do
    Postgrex.Notifications.unlisten(conn, ref)
    GenServer.stop(conn)
    Backend.disconnected(channel)
    terminate(reason, %State{state | conn: nil, ref: nil})
  end

  ##
  # Terminated.
  defp terminated(:normal, %State{channel: %Channel{} = channel}) do
    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect channel}"
    end)
  end
  defp terminated(reason, %State{channel: %Channel{} = channel}) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect channel} due to #{inspect reason}"
    end)
  end

  #########
  # Helpers

  @doc false
  def postgres_options(%Channel{namespace: namespace}) do
    options = get_namespace_options(namespace)
    connection_options = gen_connection_options(namespace)
    Keyword.merge(options, connection_options)
  end

  @doc false
  def get_namespace_options(Yggdrasil) do
    Skogsra.get_app_env(:yggdrasil, :postgres, default: [])
  end
  def get_namespace_options(namespace) do
    Skogsra.get_app_env(:yggdrasil, :postgres, default: [], domain: namespace)
  end

  @doc false
  def gen_connection_options(namespace) do
    [hostname: get_hostname(namespace),
     port: get_port(namespace),
     username: get_username(namespace),
     password: get_password(namespace),
     database: get_database(namespace)]
  end

  @doc false
  def get_value(namespace, key, default) do
    name = Settings.gen_env_name(namespace, key, "_YGGDRASIL_POSTGRES_")
    Skogsra.get_app_env(:yggdrasil, key,
      domain: [namespace, :postgres],
      default: default,
      name: name
    )
  end

  @doc false
  def get_hostname(Yggdrasil) do
    Settings.yggdrasil_postgres_hostname()
  end
  def get_hostname(namespace) do
    get_value(namespace, :hostname, Settings.yggdrasil_postgres_hostname())
  end

  @doc false
  def get_port(Yggdrasil) do
    Settings.yggdrasil_postgres_port()
  end
  def get_port(namespace) do
    get_value(namespace, :port, Settings.yggdrasil_postgres_port())
  end

  @doc false
  def get_username(Yggdrasil) do
    Settings.yggdrasil_postgres_username()
  end
  def get_username(namespace) do
    get_value(namespace, :username, Settings.yggdrasil_postgres_username())
  end

  @doc false
  def get_password(Yggdrasil) do
    Settings.yggdrasil_postgres_password()
  end
  def get_password(namespace) do
    get_value(namespace, :password, Settings.yggdrasil_postgres_password())
  end

  @doc false
  def get_database(Yggdrasil) do
    Settings.yggdrasil_postgres_database()
  end
  def get_database(namespace) do
    get_value(namespace, :database, Settings.yggdrasil_postgres_database())
  end
end
