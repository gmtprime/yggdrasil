defmodule Yggdrasil do
  @moduledoc """
  > *Yggdrasil* is an immense mythical tree that connects the nine worlds in
  > Norse cosmology.

  `Yggdrasil` manages subscriptions to channels/queues in several brokers with
  the possibility to add more. Simple Redis, RabbitMQ and PostgreSQL adapters
  are implemented. Message passing is done through `Phoenix.PubSub` adapters.

  `Yggdrasil` also manages publishing pools to Redis, RabbitMQ and PostgreSQL
  using `:pool_boy` library.

  This library provides three functions

    * For clients: `Yggdrasil.subscribe/1` and `Yggdrasil.unsubscribe/1`.
    * For servers: `Yggdrasil.publish/2`.

  And the channels can be defined with the structure `Yggdrasil.Channel`, i.e:

  ```elixir
  channel = %Yggdrasil.Channel{
    name: "redis_channel",
    transformer: Yggdrasil.Transformer.Default,
    adapter: Yggdrasil.Distributor.Adapter.Redis,
    namespace: TestRedis
  }
  ```

  where `name` is the name of the channel understood by the adapter. In this
  case the `adapter` used is `Yggdrasil.Distributor.Adapter.Redis` that
  provides a basic fault tolerant subscription to Redis channel
  `"redis_channel"`, so the channel should be a string. Also for that reason
  this channel would be used only by subscribers so the `transformer` module
  should have the function `decode/2` to decode the messages coming from Redis
  to the subscribers. The default `transformer` module does nothing to the
  incoming message, so it should be a string. If no `transformer` is supplied,
  then it's used the default `transformer` `Yggdrasil.Default.Transformer`.
  The `namespace` tells `Yggdrasil` which adapter configuration should be used,
  i.e:

  ```elixir
  use Mix.Config

  config :yggdrasil, TestRedis,
    redis: [host: "localhost"]
  ```

  this allows you to have several connection configurations for the same
  broker. By default, the `namespace` is `Yggdrasil` if no `namespace` is
  supplied.

  # General Example

  It's possible to define custom transformers to _decode_ and _encode_ messages
  _from_ and _to_ the brokers respectively i.e:

  ```elixir
  defmodule QuoteTransformer do
    use Yggdrasil.Transformer

    alias Yggdrasil.Channel

    def decode(%Channel{} = _channel, message) do
      with {:ok, quoted} <- Code.string_to_quoted(message),
           {encoded, _} <- Code.eval_quoted(quoted),
           do: {:ok, encoded}
      end

    def encode(%Channel{} = _channel, data) do
      encoded = inspect(data)
      {:ok, encoded}
    end
  end
  ```

  and using the RabbitMQ adapter the subscription channel would be:

  ```elixir
  iex(1)> sub_chan = %Yggdrasil.Channel{
    name: {"amq.topic", "quotes"},
    adapter: Yggdrasil.Distributor.Adapter.RabbitMQ,
    transformer: QuoteTransformer
  }
  ```
  where the `name` of the channel for this adapter is a tuple with the
  exchange name and the routing key and the configuration doesn't have a
  namespace i.e:

  ```elixir
  use Mix.Config

  config :yggdrasil,
    rabbitmq: [host: "localhost"]
  ```

  and the publication channel would be:

  ```elixir
  iex(2)> pub_chan = %Yggdrasil.Channel{
    name: {"amq.topic", "quotes"},
    adapter: Yggdrasil.Publisher.Adapter.RabbitMQ,
    transformer: QuoteTransformer
  }
  ```

  Using this in `IEx`:

  ```elixir
  iex(3)> Yggdrasil.subscribe(sub_chan)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED,
   %Yggdrasil.Channel{adapter: Yggdrasil.Distributor.Adapter.RabbitMQ,
     name: {"amq.topic", "quotes"}, namespace: nil,
     transformer: QuoteTransformer}}
  iex(5)> Yggdrasil.publish(pub_chan, %{"answer" => 42})
  :ok
  iex(6)> flush()
  {:Y_EVENT,
   %Yggdrasil.Channel{adapter: Yggdrasil.Distributor.Adapter.RabbitMQ,
     name: {"amq.topic", "quotes"}, namespace: nil,
     transformer: QuoteTransformer},
   %{"answer" => 42}
  }
  ```

  The available subscription adapters are:

    * `Yggdrasil.Distributor.Adapter.Elixir` which uses `Phoenix.PubSub`
    directly as broker. Channel names can be any Elixir term.
    * `Yggdrasil.Distributor.Adapter.Redis` which uses `Redis` as broker.
    Channel names should be strings. Namespaces are relevant to keep several
    connection configurations.
    * `Yggdrasil.Distributor.Adapter.RabbitMQ` which uses `RabbitMQ` as broker.
    Channel names should be tuples with the name of the exchange as first
    element and the routing key as second element. Namespaces are relevant to
    keep several connection configurations.
    * `Yggdrasil.Distributor.Adapter.Postgres` which uses `Postgres` as broker.
    Channel names should be strings. Namespaces are relevant to keep several
    connection configurations.

  The available publishing adapters are:

    * `Yggdrasil.Publisher.Adapter.Elixir` which uses `Phoenix.PubSub`
    directly as broker. Channel names can be any Elixir term.
    * `Yggdrasil.Publisher.Adapter.Redis` which uses `Redis` as broker.
    Channel names should be strings. Namespaces are relevant to keep several
    connection configurations.
    * `Yggdrasil.Publisher.Adapter.RabbitMQ` which uses `RabbitMQ` as broker.
    Channel names should be tuples with the name of the exchange as first
    element and the routing key as second element. Namespaces are relevant to
    keep several connection configurations.
    * `Yggdrasil.Publisher.Adapter.Postgres` which uses `Postgres` as broker.
    Channel names should be strings. Namespaces are relevant to keep several
    connection configurations.

  The only available transformer module is `Yggdrasil.Transformer.Default` and
  does nothing to the messages.

  # Configuration

  There are several configuration options and all of them should be in the
  general configuration for `Yggdrasil`:

    * `pubsub_adapter` - `Phoenix.PubSub` adapter. By default
    `Phoenix.PubSub.PG2` is used.
    * `pubsub_name` - Name of the `Phoenix.PubSub` adapter. By default is
    `Yggdrasil.PubSub`.
    * `pubsub_options` - Options of the `Phoenix.PubSub` adapter. By default
    are `[pool_size: 1]`.
    * `publisher_options` - `Poolboy` options. By default are
    `[size: 5, max_overflow: 10]`.
    * `registry` - Process name registry. By default is used `ExReg`.

  Also it can be specified the connection configurations with or without
  namespace:

    * `redis` - List of options of `Redix`:
      + `host` - Redis hostname.
      + `port` - Redis port.
      + `password` - Redis password.
    * `rabbitmq` - List of options of `AMQP`:
      + `host` - RabbitMQ hostname.
      + `port` - RabbitMQ port.
      + `username` - Username.
      + `password` - Password.
      + `virtual_host` - Virtual host.
    * `postgres` - List of options of `Postgrex`:
      + `hostname` - Postgres hostname.
      + `port` - Postgres port.
      + `username` - Postgres username.
      + `password` - Postgres password.
      + `database` - Postgres database name.
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
