defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator do
  @moduledoc """
  Generator of RabbitMQ connection pools.
  """
  use Supervisor
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Pool
  alias Yggdrasil.Settings

  alias AMQP.Channel

  @registry Settings.registry()

  ############
  # Client API

  @doc """
  Starts a RabbitMQ connection pool generator with optional `Supervisor`
  `options`.
  """
  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a RabbitMQ connection pool `generator`.
  """
  def stop(generator) do
    for {_, pid, _, _} <- Supervisor.which_children(generator) do
      try do
        Pool.stop(pid)
      catch
        _, _ -> :ok
      end
    end
    Supervisor.stop(generator)
  end

  @doc """
  Starts a RabbitMQ connection pool for a `namespace`.
  """
  def connect(namespace) do
    connect(__MODULE__, namespace)
  end

  @doc false
  def connect(generator, namespace) do
    name = {Pool, namespace}
    case @registry.whereis_name(name) do
      :undefined ->
        via_tuple = {:via, @registry, name}
        Supervisor.start_child(generator, [namespace, [name: via_tuple]])
      pid ->
        {:ok, pid}
    end
  end

  @doc """
  Opens a RabbitMQ channel for a `namespace`.
  """
  def open_channel(namespace) do
    with {:ok, conn} <- Pool.get_connection(namespace) do
      Channel.open(conn)
    end
  end

  @doc """
  Closes a RabbitMQ `channel`.
  """
  def close_channel(channel) do
    Channel.close(channel)
  end

  #####################
  # Supervisor callback

  @doc false
  def init(_) do
    import Supervisor.Spec

    children = [
      supervisor(Pool, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
