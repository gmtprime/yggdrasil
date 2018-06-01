defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.Pool do
  @moduledoc """
  This module defines a RabbitMQ connection pool identified by a namespace.
  """
  use Supervisor
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection, as: Conn
  alias Yggdrasil.Settings

  @registry Settings.registry()

  ############
  # Client API

  @doc """
  Starts a RabbitMQ connection pool for a `namespace` with some optional
  `Supervisor` `options`.
  """
  def start_link(namespace, options \\ []) do
    Supervisor.start_link(__MODULE__, namespace, options)
  end

  @doc """
  Stops the `supervisor`.
  """
  def stop(supervisor) do
    for {module, child, _, _} <- Supervisor.which_children(supervisor) do
      try do
        apply(module, :stop, [child])
      catch
        _, _ -> :ok
      end
    end
  end

  @doc """
  Gets a RabbitMQ connection for a `namespace`.
  """
  def get_connection(namespace) do
    via_tuple = {:via, @registry, {RabbitMQ.Poolboy, namespace}}
    :poolboy.transaction(via_tuple, fn worker ->
      Conn.get_connection(worker)
    end)
  end

  #####################
  # Supervisor callback

  @doc false
  def init(namespace) do
    import Supervisor.Spec

    via_tuple = {:via, @registry, {RabbitMQ.Poolboy, namespace}}
    poolargs = [
      name: via_tuple,
      worker_module: Conn
    ] ++ subscriber_options(namespace)

    children = [
      :poolboy.child_spec(via_tuple, poolargs, namespace)
    ]

    supervise(children, strategy: :one_for_one)
  end

  #########
  # Helpers

  @doc false
  def subscriber_options(Yggdrasil) do
    Settings.yggdrasil_rabbitmq_subscriber_options()
  end
  def subscriber_options(namespace) do
    Skogsra.get_app_env(:yggdrasil, :subscriber_options,
      domain: [namespace, :rabbitmq],
      default: Settings.yggdrasil_rabbitmq_subscriber_options()
    )
  end
end
