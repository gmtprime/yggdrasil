# Yggdrasil

[![Build Status](https://travis-ci.org/gmtprime/yggdrasil.svg?branch=master)](https://travis-ci.org/gmtprime/yggdrasil) [![Hex pm](http://img.shields.io/hexpm/v/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil) [![hex.pm downloads](https://img.shields.io/hexpm/dt/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil) [![Deps Status](https://beta.hexfaktor.org/badge/all/github/gmtprime/yggdrasil.svg)](https://beta.hexfaktor.org/github/gmtprime/yggdrasil) [![Inline docs](http://inch-ci.org/github/gmtprime/yggdrasil.svg?branch=master)](http://inch-ci.org/github/gmtprime/yggdrasil)

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
      when message: term
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

- `name` - It's the name of the channel. For `Redis` adapter, the name of
  the channel is a string.
- `transformer` - Module that contains the functions `decode/2` and
  `encode/2` to transform the messages. The default `transformer`
  `Yggdrasil.Default.Transformer` module does nothing to the messages.
- `adapter` - It's the adapter to be used for subscriptions and/or
  publishing. In this case `:redis` is the adapter used both for
  subscriptions and publishing.
- `namespace`: The namespace for the adapter configuration to allow several
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

For more information about configuration using OS environment variables look at the module `Yggdrasil.Settings`.

## Installation

`Yggdrasil` is available as a Hex package. To install, add it to your
dependencies in your `mix.exs` file:

```elixir
def deps do
  [{:yggdrasil, "~> 3.2"}]
end
```

and ensure `Yggdrasil` is started before your application:

```elixir
def application do
  [applications: [:yggdrasil]]
end

```
## Relevant projects used

  * [`ExReg`](https://github.com/gmtprime/exreg): rich process name registry.
  * [`Poolboy`](https://github.com/devinus/poolboy): A hunky Erlang worker pool
  factory.
  * [`VersionCheck`](https://github.com/gmtprime/version_check): Alerts of new
  application versions in Hex.
  * [`Redix.PubSub`](https://github.com/whatyouhide/redix_pubsub): Redis pubsub.
  * [`AMQP`](https://github.com/pma/amqp): RabbitMQ pubsub.
  * [`Postgrex`](https://github.com/elixir-ecto/postgrex): PostgreSQL pubsub.
  * [`Connection`](https://github.com/fishcakez/connection): wrapper over
  `GenServer` to handle connections.
  * [`Credo`](https://github.com/rrrene/credo): static code analysis tool for
  the Elixir language.
  * [`InchEx`](https://github.com/rrrene/inch_ex): Mix task that gives you
  hints where to improve your inline docs.

## Author

Alexander de Sousa.

## License

`Yggdrasil` is released under the MIT License. See the LICENSE file for further
details.
