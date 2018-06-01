defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection do
  @moduledoc """
  This module defines a RabbitMQ connection handler. It does not connect until
  a process request a connection.
  """
  use Bitwise
  use Connection

  require Logger

  alias Yggdrasil.Settings

  alias AMQP.Connection, as: Conn

  defstruct [:namespace, :conn, :backoff, :retries]
  alias __MODULE__, as: State

  ############
  # Public API

  @doc """
  Starts a RabbitMQ connection handler with a `namespace` to get the options
  to connect to RabbitMQ. Additionally, `GenServer` `options` can be provided.
  """
  def start_link(namespace, options  \\ []) do
    state = %State{namespace: namespace, retries: 0}
    Connection.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops the RabbitMQ connection handler with its `pid` with an optional
  `reason`.
  """
  def stop(pid, reason \\ :normal) do
    GenServer.stop(pid, reason)
  end

  @doc """
  Gets the RabbitMQ connection from the process identified by a `pid`.
  """
  def get_connection(pid) do
    Connection.call(pid, :get)
  end

  ######################
  # Connection callbacks

  @doc false
  def init(%State{} = state) do
    Process.flag(:trap_exit, true)
    {:connect, :init, state}
  end

  @doc false
  def connect(_, %State{namespace: namespace, conn: nil} = state) do
    options = rabbitmq_options(namespace)
    try do
      with {:ok, conn} <- Conn.open(options) do
        Process.monitor(conn.pid)
        Logger.debug(fn ->
          "#{__MODULE__} opened a connection with RabbitMQ" <>
          " #{inspect namespace}"
        end)
        new_state = %State{state | conn: conn, retries: 0, backoff: nil}
        {:ok, new_state}
      else
        error ->
          backoff(error, state)
      end
    catch
      :error, reason ->
        backoff({:error, reason}, state)
      error, reason ->
        backoff({:error, {error, reason}}, state)
    end
  end

  @doc false
  def disconnect(_, %State{conn: nil} = state) do
    disconnected(state)
  end
  def disconnect(info, %State{conn: conn} = state) do
    Conn.close(conn)
    disconnect(info, %State{state | conn: nil})
  end

  @doc false
  def handle_call(_, _from, %State{conn: nil, backoff: until} = state) do
    new_backoff = until - :os.system_time(:millisecond)
    new_backoff = if new_backoff < 0, do: 0, else: new_backoff
    {:reply, {:backoff, new_backoff}, state}
  end
  def handle_call(:get, _from, %State{conn: conn} = state) do
    {:reply, {:ok, conn}, state}
  end
  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def handle_info({:DOWN, _, _, pid, _}, %State{conn: %{pid: pid}} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :down, new_state}
  end
  def handle_info({:EXIT, pid, _}, %State{conn: %{pid: pid}} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :exit, new_state}
  end
  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(reason, %State{conn: nil} = state) do
    terminated(reason, state)
  end
  def terminate(reason, %State{conn: conn} = state) do
    Conn.close(conn)
    terminate(reason, %State{state | conn: nil})
  end

  ################
  # Config helpers

  @doc false
  def rabbitmq_options(namespace) do
    options = get_namespace_options(namespace)
    connection_options = gen_connection_options(namespace)
    Keyword.merge(options, connection_options)
  end

  @doc false
  def get_namespace_options(Yggdrasil) do
    :yggdrasil
    |> Skogsra.get_app_env(:rabbitmq, default: [])
    |> Keyword.pop(:subscriber_options)
    |> elem(1)
  end
  def get_namespace_options(namespace) do
    :yggdrasil
    |> Skogsra.get_app_env(:rabbitmq, default: [], domain: namespace)
    |> Keyword.pop(:subscriber_options)
    |> elem(1)
  end

  @doc false
  def gen_connection_options(namespace) do
    [host: get_hostname(namespace),
     port: get_port(namespace),
     username: get_username(namespace),
     password: get_password(namespace),
     virtual_host: get_virtual_host(namespace)]
  end

  @doc false
  def get_value(namespace, key, default) do
    name = Settings.gen_env_name(namespace, key, "_YGGDRASIL_RABBIT_")
    Skogsra.get_app_env(:yggdrasil, key,
      domain: [namespace, :rabbitmq],
      default: default,
      name: name
    )
  end

  @doc false
  def get_hostname(Yggdrasil) do
    Settings.yggdrasil_rabbitmq_hostname()
  end
  def get_hostname(namespace) do
    get_value(namespace, :hostname, Settings.yggdrasil_rabbitmq_hostname())
  end

  @doc false
  def get_port(Yggdrasil) do
    Settings.yggdrasil_rabbitmq_port()
  end
  def get_port(namespace) do
    get_value(namespace, :port, Settings.yggdrasil_rabbitmq_port())
  end

  @doc false
  def get_username(Yggdrasil) do
    Settings.yggdrasil_rabbitmq_username()
  end
  def get_username(namespace) do
    get_value(namespace, :username, Settings.yggdrasil_rabbitmq_username())
  end

  @doc false
  def get_password(Yggdrasil) do
    Settings.yggdrasil_rabbitmq_password()
  end
  def get_password(namespace) do
    get_value(namespace, :password, Settings.yggdrasil_rabbitmq_password())
  end

  @doc false
  def get_virtual_host(Yggdrasil) do
    Settings.yggdrasil_rabbitmq_virtual_host()
  end
  def get_virtual_host(namespace) do
    get_value(namespace, :virtual_host, Settings.yggdrasil_rabbitmq_virtual_host())
  end

  @doc false
  def get_max_retries(Yggdrasil) do
    Settings.yggdrasil_rabbitmq_max_retries()
  end
  def get_max_retries(namespace) do
    get_value(namespace, :max_retries, Settings.yggdrasil_rabbitmq_max_retries())
  end

  @doc false
  def get_slot_size(Yggdrasil) do
    Settings.yggdrasil_rabbitmq_slot_size()
  end
  def get_slot_size(namespace) do
    get_value(namespace, :slot_size, Settings.yggdrasil_rabbitmq_slot_size())
  end

  #########
  # Helpers

  @doc false
  def calculate_backoff(
    %State{namespace: namespace, retries: retries} = state
  ) do
    max_retries = get_max_retries(namespace)
    new_retries = if retries == max_retries, do: retries, else: retries + 1

    slot_size = get_slot_size(namespace)
    new_backoff = (2 <<< new_retries) * Enum.random(1..slot_size) # ms

    until = :os.system_time(:millisecond) + new_backoff
    new_state = %State{state | backoff: until, retries: new_retries}

    {new_backoff, new_state}
  end

  @doc false
  def backoff(error, %State{namespace: namespace} = state) do
    {new_backoff, new_state} = calculate_backoff(state)
    Logger.warn(fn ->
      "#{__MODULE__} cannot open connection to RabbitMQ" <>
      " for #{inspect namespace} due to #{inspect error}"
    end)

    {:backoff, new_backoff, new_state}
  end

  @doc false
  def disconnected(%State{namespace: namespace} = state) do
    Logger.warn(fn ->
      "#{__MODULE__} disconnected from RabbitMQ for #{inspect namespace}"
    end)
    backoff(:disconnected, state)
  end

  @doc false
  def terminated(:normal, %State{namespace: namespace}) do
    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect namespace}"
    end)
  end
  def terminated(reason, %State{namespace: namespace}) do
    Logger.warn(fn ->
      "Stopped #{__MODULE__} for #{inspect namespace}" <>
      " due to #{inspect reason}"
    end)
  end
end
