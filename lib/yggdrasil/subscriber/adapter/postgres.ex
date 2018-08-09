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
  use Bitwise
  use Connection

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Settings

  defstruct [:publisher, :channel, :conn, :ref, :retries]
  alias __MODULE__, as: State

  ############
  # Client API

  @doc """
  Starts a Postgres distributor adapter in a `channel` with some distributor
  `publisher` and optionally `GenServer` `options`.
  """
  def start_link(%Channel{} = channel, publisher, options \\ []) do
    state = %State{publisher: publisher, channel: channel, retries: 0}
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
    {backoff, new_state} = calculate_backoff(state)
    Logger.warn(fn ->
      "#{__MODULE__} cannot connect to Postgres #{inspect channel}" <>
      " due to #{inspect error}. Backing off for #{inspect backoff} ms"
    end)
    {:backoff, backoff, new_state}
  end

  ##
  # Connected.
  defp connected(conn, ref, %State{channel: %Channel{} = channel} = state) do
    Process.monitor(conn)
    Logger.debug(fn ->
      "#{__MODULE__} connected to Postgres #{inspect channel}"
    end)
    new_state = %State{state | conn: conn, ref: ref, retries: 0}
    Backend.connected(channel)
    {:ok, new_state}
  end

  @doc false
  def disconnect(_info, %State{conn: nil, ref: nil} = state) do
    disconnected(state)
  end
  def disconnect(:down, %State{channel: channel} = state) do
    Backend.disconnected(channel)
    disconnect(:down, %State{state | conn: nil, ref: nil})
  end
  def disconnect(:exit, %State{channel: channel} = state) do
    Backend.disconnected(channel)
    disconnect(:exit, %State{state | conn: nil, ref: nil})
  end

  ##
  # Disconnected.
  defp disconnected(%State{channel: %Channel{} = channel} = state) do
    Logger.warn(fn ->
      "#{__MODULE__} disconnected from Postgres #{inspect channel}"
    end)
    backoff(:disconnected, state)
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
    {:disconnect, :down, state}
  end
  def handle_info({:EXIT, _, _}, %State{} = state) do
    {:disconnect, :exit, state}
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
  def calculate_backoff(
    %State{channel: %Channel{namespace: namespace}, retries: retries} = state
  ) do
    max_retries = get_max_retries(namespace)
    new_retries = if retries == max_retries, do: retries, else: retries + 1

    slot_size = get_slot_size(namespace)
    new_backoff = (2 <<< new_retries) * Enum.random(1..slot_size) # ms

    new_state = %State{state | retries: new_retries}

    {new_backoff, new_state}
  end

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

  @doc false
  def get_max_retries(Yggdrasil) do
    Settings.yggdrasil_postgres_max_retries()
  end
  def get_max_retries(namespace) do
    get_value(
      namespace,
      :max_retries,
      Settings.yggdrasil_postgres_max_retries()
    )
  end

  @doc false
  def get_slot_size(Yggdrasil) do
    Settings.yggdrasil_postgres_slot_size()
  end
  def get_slot_size(namespace) do
    get_value(namespace, :slot_size, Settings.yggdrasil_postgres_slot_size())
  end
end
