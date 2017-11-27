defmodule Yggdrasil do
  @moduledoc """
  > *Yggdrasil* is an immense mythical tree that connects the nine worlds in
  > Norse cosmology.

  `Yggdrasil` manages subscriptions to channels/queues in several brokers with
  the possibility to add more. Simple Redis, RabbitMQ and PostgreSQL adapters
  are implemented. Message passing is done through `Phoenix.PubSub` adapters.

  `Yggdrasil` also manages publishing pools to Redis, RabbitMQ and PostgreSQL
  using `:poolboy` library.

  This library provides three functions i.e:

    + To subscribe:
      ```elixir
      Yggdrasil.subscribe(Yggdrasil.Channel.t()) :: :ok
      ```
    + To unsubscribe:
      ```elixir
      Yggdrasil.unsubscribe(Yggdrasil.Channel.t()) :: :ok
      ```
    + To publish:
      ```elixir
      Yggdrasil.publish(Yggdrasil.Channel.t(), message()) :: :ok
        when message: term()
      Yggdrasil.publish(Yggdrasil.Channel.t(), message(), options()) :: :ok
        when message: term(), options: Keyword.t()
      ```

  On subscription, the client receives a message with the following structure:

  ```elixir
  {:Y_CONNECTED, Yggdrasil.Channel.t()}
  ```

  and when the server publishes a message to the channel the message received
  by the clients has the following structure:

  ```elixir
  {:Y_EVENT, Yggdrasil.Channel.t(), message()} when message: term()
  ```

  The channels can be defined with the structure `Yggdrasil.Channel.t()`, e.g:

  ```elixir
  channel = %Yggdrasil.Channel{
    name: "redis_channel",
    transformer: Yggdrasil.Transformer.Default,
    adapter: :redis,
    namespace: TestRedis
  }
  ```

  where:

    + `name` - It's the name of the channel. For `Redis` adapter, the name of
    the channel is a string.
    + `transformer` - Module that contains the functions `decode/2` and
    `encode/2` to transform the messages. The default `transformer`
    `Yggdrasil.Default.Transformer` module does nothing to the messages.
    + `adapter` - It's the adapter to be used for subscriptions and/or
    publishing. In this case `:redis` is the adapter used both for
    subscriptions and publishing.
    + `namespace`: The namespace for the adapter configuration to allow several
    adapter configurations run at once depending on the needs of the system. By
    default is `Yggdrasil` e.g:
      ```elixir
      use Mix.Config

      config :yggdrasil,
        redis: [hostname: "localhost"]
      ```
    but for `TestRedis` namespace would be like this:
      ```elixir
      use Mix.Config

      config: :yggdrasil, TestRedis,
        redis: [hostname: "localhost"]
      ```

  # Small Example

  The following example uses the Elixir distribution to send the messages. It
  is equivalent to the Redis, RabbitMQ and Postgres distributions when a
  connection configuration is supplied:

  ```elixir
  iex(1)> Yggdrasil.subscribe(%Yggdrasil.Channel{name: "channel"})
  iex(2)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: "channel", (...)}}
  ```

  and to publish a for the subscribers:

  ```elixir
  iex(3)> Yggdrasil.publish(%Yggdrasil.Channel{name: "channel"}, "message")
  iex(4)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: "channel", (...)}, "message"}
  ```

  # Adapters

  The provided subscription adapters are the following (all are equivalents):

    * For `Elixir`: `Yggdrasil.Subscriber.Adapter.Elixir` and
    `Yggdrasil.Distributor.Adapter.Elixir`.
    * For `Redis`: `Yggdrasil.Subscriber.Adapter.Redis` and
    `Yggdrasil.Distributor.Adapter.Redis`.
    * For `RabbitMQ`: `Yggdrasil.Subscriber.Adapter.RabbitMQ` and
    `Yggdrasil.Distributor.Adapter.RabbitMQ`.
    * For `Postgres`: `Yggdrasil.Subscriber.Adapter.Postgres` and
    `Yggdrasil.Distributor.Adapter.Postgres`.

  The provided publisher adapters are the following:

    * For `Elixir`: `Yggdrasil.Publisher.Adapter.Elixir`.
    * For `Redis`: `Yggdrasil.Publisher.Adapter.Redis`.
    * For `RabbitMQ`: `Yggdrasil.Publisher.Adapter.RabbitMQ`.
    * For `Postgres`: `Yggdrasil.Publisher.Adapter.Postgres`.

  Also there is possible to use hibrid adapters. They work both subscriptions
  and publishing (recommended):

    * For `Elixir`: `:elixir` and `Yggdrasil.Elixir`.
    * For `Redis`: `:redis` and `Yggdrasil.Redis`.
    * For `RabbitMQ`: `:rabbitmq` and `Yggdrasil.RabbitMQ`.
    * For `Postgres`: `:postgres` and `Yggdrasil.Postgres`.

  The format for the channels for every adapter is the following:

    * For `Elixir` adapter: any valid term.
    * For `Redis` adapter: a string.
    * For `RabbitMQ` adapter: a tuple with exchange and routing key.
    * For `Postgres` adapter: a string.

  # Custom Transformers

  The only available transformer module is `Yggdrasil.Transformer.Default` and
  does nothing to the messages. It's possible to define custom transformers to
  _decode_ and _encode_ messages _from_ and _to_ the brokers respectively e.g:

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

  and using the RabbitMQ adapter the channel would be:

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{
  ...(1)>   name: {"amq.topic", "quotes"},
  ...(1)>   adapter: :rabbitmq,
  ...(1)>   transformer: QuoteTransformer
  ...(1)> }
  ```

  where the `name` of the channel for this adapter is a tuple with the
  exchange name and the routing key. Then:

  ```elixir
  iex(2)> Yggdrasil.subscribe(channel)
  :ok
  iex(3)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{} = _channel}
  iex(4)> Yggdrasil.publish(channel, %{"answer" => 42})
  :ok
  iex(5)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{} = _channel, %{"answer" => 42}}
  ```

  # Configuration

  There are several configuration options and all of them should be in the
  general configuration for `Yggdrasil`:

    * `pubsub_adapter` - `Phoenix.PubSub` adapter. By default
    `Phoenix.PubSub.PG2` is used.
    * `pubsub_name` - Name of the `Phoenix.PubSub` adapter. By default is
    `Yggdrasil.PubSub`.
    * `pubsub_options` - Options of the `Phoenix.PubSub` adapter. By default
    are `[pool_size: 1]`.
    * `publisher_options` - `Poolboy` options for publishing. By default are
    `[size: 5, max_overflow: 10]`.
    * `registry` - Process name registry. By default is used `ExReg`.

  Also it can be specified the connection configurations with or without
  namespace:

    * `redis` - List of options of `Redix`:
      + `hostname` - Redis hostname.
      + `port` - Redis port.
      + `password` - Redis password.
    * `rabbitmq` - List of options of `AMQP`:
      + `hostname` - RabbitMQ hostname.
      + `port` - RabbitMQ port.
      + `username` - Username.
      + `password` - Password.
      + `virtual_host` - Virtual host.
      + `subscriber_options` - `poolboy` options for RabbitMQ subscriber. By
      default are `[size: 5, max_overflow: 10]`.
    * `postgres` - List of options of `Postgrex`:
      + `hostname` - Postgres hostname.
      + `port` - Postgres port.
      + `username` - Postgres username.
      + `password` - Postgres password.
      + `database` - Postgres database name.

  For more information about configuration using OS environment variables look
  at `Yggdrasil.Settings`.
  """
  use Application
  use VersionCheck, application: :yggdrasil

  alias Yggdrasil.Settings
  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Publisher

  @publisher_gen Yggdrasil.Publisher.Generator
  @distributor_gen Yggdrasil.Distributor.Generator
  @rabbitmq_gen Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator
  @broker Yggdrasil.Broker

  ######################
  # Subscriber functions

  @doc """
  Subscribes to a `channel`.
  """
  @spec subscribe(Channel.t()) :: :ok | {:error, term()}
  def subscribe(%Channel{} = channel) do
    channel = transform_channel(:client, channel)
    with :ok <- Backend.subscribe(channel),
         do: @broker.subscribe(@broker, channel, self())
  end

  @doc """
  Unsubscribes from a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(%Channel{} = channel) do
    channel = transform_channel(:client, channel)
    with :ok <- Backend.unsubscribe(channel),
         do: @broker.unsubscribe(@broker, channel, self())
  end

  #####################
  # Publisher functions

  @doc """
  Publishes a `message` in a `channel` with some optional `options`.
  """
  @spec publish(Channel.t(), term()) :: :ok | {:error, term()}
  @spec publish(Channel.t(), term(), Keyword.t()) :: :ok | {:error, term()}
  def publish(channel, message, options \\ [])

  def publish(%Channel{} = channel, message, options) do
    channel = transform_channel(:server, channel)
    with {:ok, _} <- @publisher_gen.start_publisher(@publisher_gen, channel),
         do: Publisher.publish(channel, message, options)
  end

  #########
  # Helpers

  @doc false
  def transform_channel(:server, %Channel{adapter: :elixir} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.Elixir}
  end
  def transform_channel(:server, %Channel{adapter: :redis} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.Redis}
  end
  def transform_channel(:server, %Channel{adapter: :rabbitmq} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.RabbitMQ}
  end
  def transform_channel(:server, %Channel{adapter: :postgres} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.Postgres}
  end
  def transform_channel(:client, %Channel{adapter: :elixir} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.Elixir}
  end
  def transform_channel(:client, %Channel{adapter: :redis} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.Redis}
  end
  def transform_channel(:client, %Channel{adapter: :rabbitmq} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.RabbitMQ}
  end
  def transform_channel(:client, %Channel{adapter: :postgres} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.Postgres}
  end
  def transform_channel(type, %Channel{adapter: Yggdrasil.Elixir} = channel) do
    transform_channel(type, %Channel{channel | adapter: :elixir})
  end
  def transform_channel(type, %Channel{adapter: Yggdrasil.Redis} = channel) do
    transform_channel(type, %Channel{channel | adapter: :redis})
  end
  def transform_channel(type, %Channel{adapter: Yggdrasil.RabbitMQ} = channel) do
    transform_channel(type, %Channel{channel | adapter: :rabbitmq})
  end
  def transform_channel(type, %Channel{adapter: Yggdrasil.Postgres} = channel) do
    transform_channel(type, %Channel{channel | adapter: :postgres})
  end
  def transform_channel(
    :client,
    %Channel{adapter: Yggdrasil.Distributor.Adapter.Elixir} = channel
  ) do
    transform_channel(:client, %Channel{channel | adapter: :elixir})
  end
  def transform_channel(
    :client,
    %Channel{adapter: Yggdrasil.Distributor.Adapter.Redis} = channel
  ) do
    transform_channel(:client, %Channel{channel | adapter: :redis})
  end
  def transform_channel(
    :client,
    %Channel{adapter: Yggdrasil.Distributor.Adapter.RabbitMQ} = channel
  ) do
    transform_channel(:client, %Channel{channel | adapter: :rabbitmq})
  end
  def transform_channel(
    :client,
    %Channel{adapter: Yggdrasil.Distributor.Adapter.Postgres} = channel
  ) do
    transform_channel(:client, %Channel{channel | adapter: :postgres})
  end
  def transform_channel(_, %Channel{} = channel) do
    channel
  end

  ###################
  # Application start

  @adapter Settings.pubsub_adapter()
  @name Settings.pubsub_name()
  @options Settings.pubsub_options()

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
      worker(@broker, [@distributor_gen, monitors, [name: @broker]]),
      supervisor(@rabbitmq_gen, [[name: @rabbitmq_gen]])
    ]

    opts = [strategy: :rest_for_one, name: Yggdrasil.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
