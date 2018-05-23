defmodule Yggdrasil do
  @moduledoc """
  > *Yggdrasil* is an immense mythical tree that connects the nine worlds in
  > Norse cosmology.

  `Yggdrasil` is an agnostic publisher/subscriber for (but not exclusively)
  Redis, RabbitMQ, PostgreSQL and Elixir process messaging.

  ![demo](https://raw.githubusercontent.com/gmtprime/yggdrasil/master/images/demo.gif)

  ## Small Example

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

  ## Overview

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

  ### Channels

  The channels can be defined with the structure `Yggdrasil.Channel.t()`, i.e:

  ```elixir
  @type t :: %Yggdrasil.Channel{
    adapter: adapter(),
    name: channel(),
    transformer: transformer(),
    namespace: namespace()
  }
  ```

  #### Channel `adapter`

  It's the adapter to be used for subscriptions and/or publishing. The available
  adapters are:

    * `:elixir` adapter: It's the default adapter and uses the message
      distribution built in Erlang/Elixir.
    * `:redis` adapter: It's the provided adapter for Redis.
    * `:postgres` adapter: It's the provided adapter for Postgres.
    * `:rabbitmq` adapter: It's the provided adapter for RabbitMQ.

  Custom adapters can be implemented and used by setting `adapter` to the module
  of the custom adapter.

  #### Channel `name`

  It's the name of the channel. Depending on the adapter there are limitations in
  how the name can be. For the provided adapters, the names can be as follows:

    * `:elixir` adapter: Can be any Erlang/Elixir `term()`.
    * `:redis` adapter: Should be a `binary()` without spaces.
    * `:postgres` adapter: Should be a alphanumeric `binary()`.
    * `:rabbitmq` adapter: Should be a tuple `{exchange(), routing_key()}`
      where `exchange()` and `routing_key()` are `binary()`.

  #### Channel `transformer`

  It's a module that encodes the messages published in a channel and decodes the
  messages coming from a channel. There are two transformers provided with
  `Yggdrasil`:

    * `:default` transformer: Does nothing to the messages.
    * `:json` transformer: Encodes `map()` to JSON `binary()` and decodes JSON
      `binary()` as `map()`.

  Apart from the transformers provided it's possible to define custom
  transformers to _decode_ and _encode_ messages _from_ and _to_ the adapters
  respectively e.g by using a libray like
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

  #### Channel `namespace`

  By default, all the namespaces are `Yggdrasil`, but if, for example, you have
  several different Redis servers you want to subscribe, you can use the
  namespaces in the configuration to differentiate them e.g:

  ```elixir
  use Mix.Config

  config :yggdrasil, RedisOne,
    redis: [hostname: "redis.one"]

  config :yggdrasil, RedisTwo,
    redis: [hostname: "redis.two"]
  ```

  ## Configuration

  `Yggdrasil` works out of the box with no special configuration at all.

  Although all the adapters try to connect with the different services using the
  default credentials, custom connection configurations can be set with or
  without namespaces.

  ### Redis Configuration

  Uses the list of options of `Redix`, but the more relevant options are shown
  below:
    * `hostname` - Redis hostname (defaults to `"localhost"`).
    * `port` - Redis port (defaults to `6379`).
    * `password` - Redis password (defaults to `""`).

  The following shows a configuration with and without namespace:

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

  ### RabbitMQ Configuration

  Uses the list of options of `AMQP`, but the more relevant options are shown
  below:
    * `hostname` - RabbitMQ hostname (defaults to `"localhost"`).
    * `port` - RabbitMQ port (defaults to `5672`)
    * `username` - Username (defaults to `"guest"`).
    * `password` - Password (defaults to `"guest"`).
    * `virtual_host` - Virtual host (defaults to `"/"`).
    * `subscriber_options` - Controls the amount of connections established with
      RabbitMQ. These are `poolboy` options for RabbitMQ subscriber (defaults to
      `[size: 5, max_overflow: 10]`).

  The following shows a configuration with and without namespace:

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

  ### Postgres Configuration

  Uses the list of options of `Postgrex`, but the more relevant options are shown
  below:
    * `hostname` - Postgres hostname (defaults to `"localhost"`)
      + `port` - Postgres port (defaults to `5432`).
      + `username` - Postgres username (defaults to `"postgres"`).
      + `password` - Postgres password (defaults to `"postgres"`).
      + `database` - Postgres database name (defaults to `"postgres"`).

  The following shows a configuration with and without namespace:

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

  ### Message Distribution Configuration

  `Yggdrasil` uses  `Phoenix.PubSub` for the message distribution. The following
  options show how to configure it:

    * `pubsub_adapter` - `Phoenix.PubSub` adapter (defaults to
      `Phoenix.PubSub.PG2`).
    * `pubsub_name` - Name of the `Phoenix.PubSub` adapter (defaults to
      `Yggdrasil.PubSub`).
    * `pubsub_options` - Options of the `Phoenix.PubSub` adapter (defaults
      to `[pool_size: 1]`).

  The rest of the options are for configuring the publishers and process name
  registry:

    * `publisher_options` - `Poolboy` options for publishing. Controls the amount
      of connections established with the service (defaults to
      `[size: 5, max_overflow: 10]`).
    * `registry` - Process name registry (defaults to`ExReg`).

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
