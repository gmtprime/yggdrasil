# Yggdrasil

[![Build Status](https://travis-ci.org/gmtprime/yggdrasil.svg?branch=master)](https://travis-ci.org/gmtprime/yggdrasil) [![Hex pm](http://img.shields.io/hexpm/v/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil) [![hex.pm downloads](https://img.shields.io/hexpm/dt/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil) [![Deps Status](https://beta.hexfaktor.org/badge/all/github/gmtprime/yggdrasil.svg)](https://beta.hexfaktor.org/github/gmtprime/yggdrasil) [![Inline docs](http://inch-ci.org/github/gmtprime/yggdrasil.svg?branch=master)](http://inch-ci.org/github/gmtprime/yggdrasil)


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
incoming message, so it should be a string. The `namespace` tells `Yggdrasil`
which adapter configuration should be used, i.e:

```elixir
use Mix.Config

config :yggdrasil, TestRedis,
  redis: [host: "localhost"]
```

this allows you to have several connection configurations for the same
broker.

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

## Installation

`Yggdrasil` is available as a Hex package. To install, add it to your
dependencies in your `mix.exs` file:

```elixir
def deps do
  [{:yggdrasil, "~> 3.0"}]
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
