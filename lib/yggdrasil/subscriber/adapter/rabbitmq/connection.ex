defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection do
  @moduledoc """
  This module defines a RabbitMQ connection handler. It does not connect until
  a process request a connection.
  """
  use Connection

  require Logger

  alias Yggdrasil.Settings

  defstruct [:namespace, :conn]
  alias __MODULE__, as: State

  ############
  # Public API

  @doc """
  Starts a RabbitMQ connection handler with a `namespace` to get the options
  to connect to RabbitMQ. Additionally, `GenServer` `options` can be provided.
  """
  def start_link(namespace, options  \\ []) do
    state = %State{namespace: namespace}
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
  Opens a RabbitMQ channel in the connection process identified by a `pid`.
  """
  def open_channel(pid) do
    Connection.call(pid, :open)
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
    {:ok, conn} = AMQP.Connection.open(options)
    connected(conn, state)
  catch
    _, reason ->
      backoff(reason, state)
  rescue
    error ->
      backoff(error, state)
  end

  @doc false
  def disconnect(_, %State{conn: nil} = state) do
    disconnected(state)
  end
  def disconnect(info, %State{conn: conn} = state) do
    AMQP.Connection.close(conn)
    disconnect(info, %State{state | conn: nil})
  end

  @doc false
  def handle_call(:open, _from, %State{conn: nil} = state) do
    {:reply, {:error, "Not connected"}, state}
  end
  def handle_call(:open, _from, %State{conn: conn} = state) do
    AMQP.Channel.open(conn)
  catch
    _, reason ->
      {:reply, {:ok, reason}, state}
  else
    {:ok, _} = channel ->
      {:reply, channel, state}
    error ->
      {:reply, error, state}
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
    AMQP.Connection.close(conn)
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

  #########
  # Helpers

  @doc false
  def connected(conn, %State{namespace: namespace} = state) do
    Process.monitor(conn.pid)
    metadata = [namespace: namespace]
    Logger.debug(fn ->
      "Opened a connection with RabbitMQ #{inspect metadata}"
    end)
    new_state = %State{state | conn: conn}
    {:ok, new_state}
  end

  @doc false
  def backoff(error, %State{namespace: namespace} = state) do
    metadata = [namespace: namespace, error: error]
    Logger.error(fn ->
      "Cannot open connection to RabbitMQ #{inspect metadata}"
    end)
    {:backoff, 5_000, state}
  end

  @doc false
  def disconnected(%State{namespace: namespace} = state) do
    metadata = [namespace: namespace]
    Logger.debug(fn ->
      "Disconnected from RabbitMQ #{inspect metadata}"
    end)
    {:backoff, 5_000, state}
  end

  @doc false
  def terminated(:normal, %State{namespace: namespace}) do
    metadata = [namespace: namespace]
    Logger.debug(fn ->
      "Terminated RabbitMQ connection #{inspect metadata}"
    end)
    :ok
  end
  def terminated(reason, %State{namespace: namespace}) do
    metadata = [namespace: namespace, reason: reason]
    Logger.debug(fn ->
      "Terminated RabbitMQ connection #{inspect metadata}" <>
      " with #{inspect reason}"
    end)
    :ok
  end
end
