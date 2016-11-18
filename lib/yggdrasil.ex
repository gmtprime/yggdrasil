defmodule Yggdrasil do
  @moduledoc """
  > *Yggdrasil* is an immense mythical tree that connects the nine worlds in
  > Norse cosmology.

  `Yggdrasil` manages subscriptions to channels/queues in several brokers with
  the possibility to add more. Simple Redis, RabbitMQ and PostgreSQL adapters
  are implemented. Message passing is done through `Phoenix.PubSub` adapters.

  `Yggdrasil` also manages publishing pools to Redis, RabbitMQ and PostgreSQL.
  """
  use Application
  use VersionCheck, application: :yggdrasil

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Publisher

  #############################################################################
  # Distributor functions.

  @publisher_gen Yggdrasil.Publisher.Generator
  @distributor_gen Yggdrasil.Distributor.Generator
  @broker Yggdrasil.Broker

  @doc """
  Subscribes to a `channel`.
  """
  @spec subscribe(Channel.t()) :: :ok | {:error, term()}
  def subscribe(%Channel{} = channel) do
    with :ok <- Backend.subscribe(channel),
         do: @broker.subscribe(@broker, channel, self())
  end

  @doc """
  Unsubscribes from a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(%Channel{} = channel) do
    with :ok <- Backend.unsubscribe(channel),
         do: @broker.unsubscribe(@broker, channel, self())
  end

  #############################################################################
  # Publisher function.

  @doc """
  Publishes a `message` in a `channel`.
  """
  @spec publish(Channel.t(), term()) :: :ok | {:error, term()}
  def publish(%Channel{} = channel, message) do
    with {:ok, _} <- @publisher_gen.start_publisher(@publisher_gen, channel),
         do: Publisher.publish(channel, message)
  end

  #############################################################################
  # Application start.

  @adapter Application.get_env(:yggdrasil, :pubsub_adapter, Phoenix.PubSub.PG2)
  @name Application.get_env(:yggdrasil, :pubsub_name, Yggdrasil.PubSub)
  @options Application.get_env(:yggdrasil, :pubsub_options, [pool_size: 1])

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    check_version()

    monitors = :ets.new(:monitors, [:set, :public, write_concurrency: false,
                                    read_concurrency: true])

    children = [
      supervisor(@adapter, [@name, @options]),
      supervisor(@publisher_gen, [[name: @publisher_gen]]),
      supervisor(@distributor_gen, [[name: @distributor_gen]]),
      worker(@broker, [@distributor_gen, monitors, [name: @broker]])
    ]

    opts = [strategy: :rest_for_one, name: Yggdrasil.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
