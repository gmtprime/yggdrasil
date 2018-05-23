defmodule Yggdrasil do
  @moduledoc """
  > *Yggdrasil* is an immense mythical tree that connects the nine worlds in
  > Norse cosmology.

  `Yggdrasil` is an agnostic publisher/subscriber for (but not exclusively)
  Redis, RabbitMQ, PostgreSQL and Elixir process messaging.

  ![demo](https://raw.githubusercontent.com/gmtprime/yggdrasil/master/images/demo.gif)

  This library provides three functions i.e:

    + Subscribing to a channel:
      ```elixir
      Yggdrasil.subscribe(Yggdrasil.Channel.t())
        :: :ok | {:error, term()}
      ```
      The process that subscribes will receive the following message when the
      adapter has connected successfully:
      ```elixir
      {:Y_CONNECTED, Yggdrasil.Channel.t()}
      ```
    + Unsubscribing from a channel:
      ```elixir
      Yggdrasil.unsubscribe(Yggdrasil.Channel.t())
        :: :ok | {:error, term()}
      ```
      The process that was subscribed to the channel will receive the following
      message when the adapter has disconnected successfully:
      ```elixir
      {:Y_DISCONNECTED, Yggdrasil.Channel.t()}
      ```
    + Publishing in a channel:
      ```elixir
      Yggdrasil.publish(Yggdrasil.Channel.t(), message())
        :: :ok | {:error, term()}
        when message: term()
      ```
      The processes that are subscribed to the channel will receive the following
      message:
      ```elixir
      {:Y_EVENT, Yggdrasil.Channel.t(), message()} when message: term()
      ```

  The channels can be defined with the structure `Yggdrasil.Channel.t()`, i.e:

  ```elixir
  @type t :: %Yggdrasi.Channel{
    name: elixir_channel() | redis_channel() | postgres_channel() | rabbitmq_channel() | term(),
    adapter: :elixir | :redis | :postgres | :rabbitmq | module(),
    transformer: module(),
    namespace: atom()
  } when elixir_channel: term(),
         redis_channel: binary(),
         postgres_channel: binary(),
         rabbitmq_channel: {exchange(), routing_key()},
         exchange: binary(),
         routing_key: binary()
  ```

  where:

    + `name` - It's the name of the channel.
    + `adapter` - It's the adapter to be used for subscriptions and/or
      publishing. `:elixir` is the default value and uses the message distribution
      built in Erlang/Elixir. `:redis`, `:postgres` and `:rabbitmq` are included
      with `Yggdrasil`, but other custom adapters can be used by setting `adapter`
      as the module of the new adapter.
    + `transformer` - It's a module that encodes the messages published in a
      channel and decodes the messages coming from a channel. The `:default`
      transformer send and receives the messages as is. The `:json` transformer
      only works with valid JSONs. By implementing the functions `encode/2` and
      `decode/2`, you can have a custom transformer for your data.
    + `namespace`: By default, all the namespaces are `Yggdrasil`, but if, for
      example, you have several different Redis servers you want to subscribe, you
      can use the namespaces in the configuration to differentiate them e.g:
      ```elixir
      use Mix.Config

      config :yggdrasil, RedisOne,
        redis: [hostname: "redis.one"]

      config :yggdrasil, RedisTwo,
        redis: [hostname: "redis.two"]
      ```

  # Small Example

  The following example uses the Elixir distribution to send the messages. It
  is equivalent to the Redis, RabbitMQ and Postgres distributions when a
  connection configuration is supplied:

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{name: "channel"}
  iex(2)> Yggdrasil.subscribe(channel)
  iex(3)> flush()
  {:Y_CONNECTED, _}
  ```

  and to publish a for the subscribers:

  ```elixir
  iex(4)> Yggdrasil.publish(channel, "message")
  iex(5)> flush()
  {:Y_EVENT, _, "message"}
  ```

  When the subscriber wants to stop receiving messages, then it can unsubscribe
  from the channel:

  ```elixir
  iex(6)> Yggdrasil.unsubscribe(channel)
  iex(7)> flush()
  {:Y_DISCONNECTED, _}
  ```

  # Provided adapters

  The provided subscription adapters are the following:

    * For `Elixir`: `:elixir` and `Yggdrasil.Elixir`.
    * For `Redis`: `:redis` and `Yggdrasil.Redis`.
    * For `RabbitMQ`: `:rabbitmq` and `Yggdrasil.RabbitMQ`.
    * For `Postgres`: `:postgres` and `Yggdrasil.Postgres`.

  And the format for the channels for every adapter is the following:

    * For `Elixir` adapter: any valid term.
    * For `Redis` adapter: a binary.
    * For `RabbitMQ` adapter: a tuple with exchange and routing key, both
      binaries.
    * For `Postgres` adapter: a binary.

  # Custom Transformers

  There are two transformers available:

    + `:default`: Does nothing to the messages of the channel.
    + `:json`: _encodes_ the message on publishing from a map to a binary and
      _decodes_ a binary JSON to a map.

  It's possible to define custom transformers to _decode_ and _encode_ messages
  _from_ and _to_ the adapters respectively e.g by using a libray like
  [Poison](https://github.com/devinus/poison) (`:json` uses `Jason` library) we
  can define the following transformer:

  ```elixir
  defmodule JSONTransformer do
    use Yggdrasil.Transformer

    alias Yggdrasil.Channel

    def decode(%Channel{} = _channel, message) do
      Poison.decode(message)
    end

    def encode(%Channel{} = _channel, data) when is_map(data) do
      Poison.encode(data)
    end
  end
  ```

  Then declaring the channel using `JSONTransformer` with the Redis adapter would
  be:

  and using the RabbitMQ adapter the channel would be:

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{
  ...(1)>   name: "redis_channel",
  ...(1)>   adapter: :redis,
  ...(1)>   transformer: JSONTransformer
  ...(1)> }
  ```

  # Configuration

  `Yggdrasil` works out of the box with no special configuration at all.

  Although all the adapters try to connect with the different services using the
  default credentials, custom connection configurations can be set with or
  without namespaces:

    * `redis` - List of options of `Redix`:
      + `hostname` - Redis hostname.
      + `port` - Redis port.
      + `password` - Redis password.
    ```elixir
    # Without namespace
    config :yggdrasil,
      redis: [hostname: "redis.zero"]

    # With namespace
    config :yggdrasil, RedisOne,
      redis: [
        hostname: "redis.one",
        port: 1234
      ]
    ```
    * `rabbitmq` - List of options of `AMQP`:
      + `hostname` - RabbitMQ hostname.
      + `port` - RabbitMQ port.
      + `username` - Username.
      + `password` - Password.
      + `virtual_host` - Virtual host.
      + `subscriber_options` - `poolboy` options for RabbitMQ subscriber.
        Controls the amount of connections established with RabbitMQ. By
        default are `[size: 5, max_overflow: 10]`.
    ```elixir
    # Without namespace
    config :yggdrasil,
      rabbitmq: [hostname: "rabbitmq.zero"]

    # With namespace
    config :yggdrasil, RabbitMQOne,
      rabbitmq: [
        hostname: "rabbitmq.one",
        port: 1234
      ]
    ```
    * `postgres` - List of options of `Postgrex`:
      + `hostname` - Postgres hostname.
      + `port` - Postgres port.
      + `username` - Postgres username.
      + `password` - Postgres password.
      + `database` - Postgres database name.
    ```elixir
    # Without namespace
    config :yggdrasil,
      postgres: [password: "some password"]

    # With namespace

    config :yggdrasil, PostgresOne,
      postgres: [
        password: "some other password"
      ]
    ```

  `Yggdrasil` uses  `Phoenix.PubSub` for the message distribution. The following
  options show how to configure it:

    * `pubsub_adapter` - `Phoenix.PubSub` adapter. By default
      `Phoenix.PubSub.PG2` is used.
    * `pubsub_name` - Name of the `Phoenix.PubSub` adapter. By default is
      `Yggdrasil.PubSub`.
    * `pubsub_options` - Options of the `Phoenix.PubSub` adapter. By default
      are `[pool_size: 1]`.

  The rest of the options are for configuring the publishers and process name
  registry:

    * `publisher_options` - `Poolboy` options for publishing. Controls the amount
      of connections established with the service. By default are
      `[size: 5, max_overflow: 10]`.
    * `registry` - Process name registry. By default is used `ExReg`.

  For more information about configuration using OS environment variables check
  the module `Yggdrasil.Settings`.

  ## Installation

  `Yggdrasil` is available as a Hex package. To install, add it to your
  dependencies in your `mix.exs` file:

  ```elixir
  def deps do
    [{:yggdrasil, "~> 3.3"}]
  end
  ```

  and ensure `Yggdrasil` is started before your application:

  ```elixir
  def application do
    [applications: [:yggdrasil]]
  end
  ```
  """
  use Application

  alias Yggdrasil.Settings
  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Publisher
  alias Yggdrasil.Publisher.Generator, as: PublisherGen
  alias Yggdrasil.Distributor.Generator, as: DistributorGen
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator, as: RabbitGen

  ######################
  # Subscriber functions

  @doc """
  Subscribes to a `channel`.
  """
  @spec subscribe(Channel.t()) :: :ok | {:error, term()}
  def subscribe(channel)

  def subscribe(%Channel{} = channel) do
    channel = transform_channel(:subscriber, channel)
    with :ok <- Backend.subscribe(channel) do
      DistributorGen.subscribe(channel)
    end
  end

  @doc """
  Unsubscribes from a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(channel)

  def unsubscribe(%Channel{} = channel) do
    channel = transform_channel(:subscriber, channel)
    with :ok <- Backend.unsubscribe(channel) do
      DistributorGen.unsubscribe(channel)
    end
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
    channel = transform_channel(:publisher, channel)
    with {:ok, _} <- PublisherGen.start_publisher(PublisherGen, channel) do
      Publisher.publish(channel, message, options)
    end
  end

  #########
  # Helpers

  @doc false
  def transform_channel(type, %Channel{} = channel) do
    type
    |> transform_name(channel)
    |> transform_transformer()
  end

  @doc false
  def transform_name(:publisher, %Channel{adapter: :elixir} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.Elixir}
  end
  def transform_name(:publisher, %Channel{adapter: :redis} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.Redis}
  end
  def transform_name(:publisher, %Channel{adapter: :rabbitmq} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.RabbitMQ}
  end
  def transform_name(:publisher, %Channel{adapter: :postgres} = channel) do
    %Channel{channel | adapter: Yggdrasil.Publisher.Adapter.Postgres}
  end
  def transform_name(:subscriber, %Channel{adapter: :elixir} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.Elixir}
  end
  def transform_name(:subscriber, %Channel{adapter: :redis} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.Redis}
  end
  def transform_name(:subscriber, %Channel{adapter: :rabbitmq} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.RabbitMQ}
  end
  def transform_name(:subscriber, %Channel{adapter: :postgres} = channel) do
    %Channel{channel | adapter: Yggdrasil.Subscriber.Adapter.Postgres}
  end
  def transform_name(_, %Channel{} = channel) do
    channel
  end

  @doc false
  def transform_transformer(%Channel{transformer: :default} = channel) do
    %Channel{channel | transformer: Yggdrasil.Transformer.Default}
  end
  def transform_transformer(%Channel{transformer: :json} = channel) do
    %Channel{channel | transformer: Yggdrasil.Transformer.Json}
  end
  def transform_transformer(%Channel{} = channel) do
    channel
  end

  ###################
  # Application start

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    adapter = Settings.pubsub_adapter()
    name = Settings.pubsub_name()
    options = Settings.pubsub_options()

    children = [
      supervisor(adapter, [name, options]),
      supervisor(PublisherGen, [[name: PublisherGen]]),
      supervisor(DistributorGen, [[name: DistributorGen]]),
      supervisor(RabbitGen, [[name: RabbitGen]])
    ]

    opts = [strategy: :rest_for_one, name: Yggdrasil.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
