defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection do
  @moduledoc """
  This module defines a RabbitMQ connection handler. It does not connect until
  a process request a connection.
  """
  use Connection
  alias Yggdrasil.Channel

  require Logger

  defstruct [:namespace, :conn, :ref]
  alias __MODULE__, as: State

  @doc """
  Starts a RabbitMQ connection handler with a `namespace` to get the options
  to connect to RabbitMQ. Additionally, `GenServer` `options` can be provided.
  """
  def start_link(namespace, options  \\ []) do
    state = %State{namespace: namespace, ref: make_ref()}
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
  Subscribes to an Yggdrasil channel to receive connection updates from the
  RabbitMQ connection identified by the `namespace`.
  """
  def subscribe(namespace \\ Yggdrasil) do
    channel = sub_channel(namespace)
    Yggdrasil.subscribe(channel)
  end

  @doc """
  Unsubscribes from an Yggdrasil channel to stop receiving connection
  updates from the RabbitMQ connection identified by the `namespace`.
  """
  def unsubscribe(namespace \\ Yggdrasil) do
    channel = sub_channel(namespace)
    Yggdrasil.unsubscribe(channel)
  end

  @doc """
  Opens a RabbitMQ channel.
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
    try do
      {:ok, conn} = AMQP.Connection.open(options)
      connected(conn, state)
    catch
      _, reason ->
        backoff(reason, state)
    rescue
      error ->
        backoff(error, state)
    end
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
    try do
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

  @doc false
  def connected(conn, %State{namespace: namespace} = state) do
    publish(:connected, state)
    Process.monitor(conn.pid)
    metadata = [namespace: namespace]
    Logger.debug("Opened a connection with RabbitMQ #{inspect metadata}")
    new_state = %State{state | conn: conn}
    {:ok, new_state}
  end

  @doc false
  def backoff(error, %State{namespace: namespace} = state) do
    metadata = [namespace: namespace, error: error]
    Logger.error("Cannot open connection to RabbitMQ #{inspect metadata}")
    {:backoff, 5_000, state}
  end

  @doc false
  def disconnected(%State{namespace: namespace} = state) do
    publish(:disconnected, state)
    metadata = [namespace: namespace]
    Logger.debug("Disconnected from RabbitMQ #{inspect metadata}")
    {:backoff, 5_000, state}
  end

  @doc false
  def terminated(:normal, %State{namespace: namespace} = state) do
    publish(:stopped, state)
    metadata = [namespace: namespace]
    Logger.debug("Terminated RabbitMQ connection #{inspect metadata}")
    :ok
  end
  def terminated(reason, %State{namespace: namespace} = state) do
    publish(:terminated, state)
    metadata = [namespace: namespace, reason: reason]
    Logger.debug("Terminated RabbitMQ connection #{inspect metadata}" <>
                 " with #{inspect reason}")
    :ok
  end

  #########
  # Helpers

  @doc false
  def rabbitmq_options(Yggdrasil) do
    Application.get_env(:yggdrasil, :rabbitmq, [])
  end
  def rabbitmq_options(namespace) do
    default = [rabbitmq: []]
    result = Application.get_env(:yggdrasil, namespace, default)
    Keyword.get(result, :rabbitmq, [])
  end

  @doc false
  def pub_channel(%State{namespace: namespace}) do
    %Channel{
      name: {:rabbitmq_connection, namespace},
      adapter: Yggdrasil.Publisher.Adapter.Elixir
    }
  end

  @doc false
  def publish(message, %State{ref: ref} = state) do
    channel = pub_channel(state)
    Yggdrasil.publish(channel, {message, ref})
  end

  @doc false
  def sub_channel(namespace) do
    %Channel{
      name: {:rabbitmq_connection, namespace},
      adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
  end
end
