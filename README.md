![yggdrasil logo](https://raw.githubusercontent.com/gmtprime/yggdrasil/master/priv/static/yggdrasil.png)

[![Build Status](https://travis-ci.org/gmtprime/yggdrasil.svg?branch=master)](https://travis-ci.org/gmtprime/yggdrasil) [![Hex pm](http://img.shields.io/hexpm/v/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil) [![hex.pm downloads](https://img.shields.io/hexpm/dt/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil)

> *Yggdrasil* is an immense mythical tree that connects the nine worlds in
> Norse cosmology.

`Yggdrasil` is an agnostic publisher/subscriber:

- Multi-node pubsub.
- Simple API (`subscribe/1`, `unsubscribe/1`, `publish/2`).
- Several fault tolerant adapters (RabbitMQ, Redis, PostgreSQL, GraphQL,
Ethereum).

## Small Example

The following example uses the Elixir distribution to send the messages:

```elixir
iex(1)> Yggdrasil.subscribe(name: "my_channel")
iex(2)> flush()
{:Y_CONNECTED, %Yggdrasil.Channel{(...)}}
```

and to publish a for the subscribers:

```elixir
iex(3)> Yggdrasil.publish([name: "my_channel"], "message")
iex(4)> flush()
{:Y_EVENT, %Yggdrasil.Channel{(...)}, "message"}
```

When the subscriber wants to stop receiving messages, then it can unsubscribe
from the channel:

```elixir
iex(5)> Yggdrasil.unsubscribe(name: "my_channel")
iex(6)> flush()
{:Y_DISCONNECTED, %Yggdrasil.Channel{(...)}}
```

For convinience, `Yggdrasil` is also a `GenServer` wrapper for subscribing
to one or several channels e.g:

```elixir
defmodule Subscriber do
  use Yggdrasil

  def start_link do
    channel = [name: "my_channel"]
    Yggdrasil.start_link(__MODULE__, [channel])
  end

  @impl true
  def handle_event(_channel, message, _state) do
    IO.inspect message
    {:ok, nil}
  end
end
```

## Channels

The following are the available fields for a channel:

- `adapter` - By default uses OTP message distribution using `:elixir` adapter,
  but there are several other adapters (see next section for more information).
- `name` - Depends on the adapter e.g. for `:elixir` adapter, any valid `term`
  would suffice, but for `:bridge` adapter its necessary to pass a valid channel
  as name.
- `transformer` - Decodes and encodes messages for the specified adapter.
  Defaults to `:default` (which does nothing to the message), but `Yggdrasil`
  comes with other adapter for `:json` messages.
- `backend` - Defines the distribution of the messages. Defaults to `:default`
  `Phoenix.PubSub` message distribution.
- `namespace` - Namespace for the channel configuration.

## Adapters

An adapter is a process that connects to a service and distributes its messages
among the subscribers of a channel. The following repositories have some of the
available adapters:

Adapter         | Yggdrasil Adapter     | Dependencies                                                                | Description
:-------------- | :-------------------- | :-------------------------------------------------------------------------- | :---------------------------------------------------
**OTP**         | `:elixir` (default)   | [`:yggdrasil`](https://github.com/gmtprime/yggdrasil)                       | Multi node subscriptions
**OTP**         | `:bridge`             | [`:yggdrasil`](https://github.com/gmtprime/yggdrasil)                       | Converts any adapter to multi node
**RabbitMQ**    | `:rabbitmq`           | [`:yggdrasil_rabbitmq`](https://github.com/gmtprime/yggdrasil_rabbitmq)     | Fault tolerant pubsub for exchanges and routing keys
**Redis**       | `:redis`              | [`:yggdrasil_redis`](https://github.com/gmtprime/yggdrasil_redis)           | Fault tolerant pubsub for Redis channels
**PostgreSQL**  | `:postgres`           | [`:yggdrasil_postgres`](https://github.com/gmtprime/yggdrasil_postgres)     | Fault tolerant pubsub for `PG_NOTIFY` messages
**GraphQL**     | `:graphql`            | [`:yggdrasil_graphql`](https://github.com/etherharvest/yggdrasil_graphql)   | Converts any adapter to a GraphQL subscription
**Ethereum**    | `:ethereum`           | [`:yggdrasil_ethereum`](https://github.com/etherharvest/yggdrasil_ethereum) | Fault tolerant pubsub for contract log messages

> For more information on how to use them, check the corresponding repository
> documentation.

## Transformers

A transformer is the implementation of the behaviour `Yggdrasil.Transformer`.
In essence implements two functions:

  * `decode/2` for decoding messages coming from the adapter.
  * `encode/2` for encoding messages going to the adapter

`Yggdrasil` has two implemented transformers:

  * `:default` - Does nothing to the messages and it is the default
  transformer used if no transformer has been defined.
  * `:json` - Transforms from Elixir maps to string JSONs and viceversa.

## Backends

A backend is the implementation of the behaviour `Yggdrasil.Backend`. The
module is in charge of distributing the messages with a certain format inside
`Yggdrasil`. Currently, there is only one backend, `:default`, and it is used
by default. It uses `Phoenix.PubSub` to distribute the messages.

The messages received by the subscribers when using `:default` backend are:

  * `{:Y_CONNECTED, Yggdrasil.Channel.t()}` when the connection with the
  adapter is established.
  * `{:Y_EVENT, Yggdrasil.Channel.t(), term()}` when a message is received
  from the adapter.
  * `{:Y_DISCONNECTED, Yggdrasil.Channel.t()}` when the connection with the
  adapter is finished due to disconnection or unsubscription.

## Multi node

Though `:elixir` adapter has built-in support for multi node pubsub, that's not
the case with the other adapters. To overcome this limitation, `:bridge`
adapter is capable of connecting to a remote adapter if and only if this adapter
is not present in the current node e.g. let's say we have the following:

- Node A has `:yggdrasil`.
- Node B has `:yggdrasil_rabbitmq`.
- The nodes A and B are connected.

Then is possible for the node A to connect to RabbitMQ through node B by using
the `:bridge` adapter:

For subscription:

```elixir
iex(1)> channel = [
...(1)>   name: [name: {"amq.topic", "foo"}, adapter: :rabbitmq],
...(1)>   adapter: :bridge
...(1)> ]
iex(2)> Yggdrasil.subscribe(channel)
iex(3)> flush()
{:Y_CONNECTED, %Yggdrasil.Channel{(...)}}
```

and for publishing:

```elixir
iex(1)> channel = [
...(1)>   name: [name: {"amq.topic", "foo"}, adapter: :rabbitmq],
...(1)>   adapter: :bridge
...(1)> ]
iex(2)> Yggdrasil.publish(channel, "bar")
:ok
```

## Configuration

`Yggdrasil` works out of the box with no special configuration at all. However,
it is possible to tune the publisher. The default `Yggdrasil` backend uses
`Phoenix.PubSub` and the following are the available options:

  * `pubsub_adapter` - `Phoenix.PubSub` adapter (defaults to
    `Phoenix.PubSub.PG2`).
  * `pubsub_name` - Name of the `Phoenix.PubSub` adapter (defaults to
    `Yggdrasil.PubSub`).
  * `pubsub_options` - Options of the `Phoenix.PubSub` adapter (defaults
    to `[pool_size: 1]`).

The rest of the options are for configuring the publishers and process name
registry:

  * `publisher_options` - `Poolboy` options for publishing. Controls the amount
    of connections established with the adapter service (defaults to
    `[size: 1, max_overflow: 5]`).

For more information about configuration using OS environment variables check
the module `Yggdrasil.Settings`.

## Installation

`Yggdrasil` is available as a Hex package. To install, add it to your
dependencies in your `mix.exs` file:


- For Elixir < 1.7 and Erlang < 21

  ```elixir
  def deps do
    [{:yggdrasil, "~> 4.1.2"}]
  end
  ```

- For Elixir ≥ 1.7 and Erlang ≥ 21

  ```elixir
  def deps do
    [{:yggdrasil, "~> 4.2"}]
  end
  ```

## Author

Alexander de Sousa.

## License

`Yggdrasil` is released under the MIT License. See the LICENSE file for further
details.
