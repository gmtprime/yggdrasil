defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection do
  @moduledoc """
  This module defines a RabbitMQ connection handler. It does not connect until
  a process request a connection.
  """
  use Connection

  require Logger

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

  #########
  # Helpers

  @doc false
  def rabbitmq_options(Yggdrasil) do
    :yggdrasil
    |> Application.get_env(:rabbitmq, [])
  end
  def rabbitmq_options(namespace) do
    :yggdrasil
    |> Application.get_env(namespace, [rabbitmq: []])
    |> Keyword.get(:rabbitmq, [])
    |> Keyword.pop(:subscriber_options)
    |> elem(1)
  end

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
