# Yggdrasil

[![Build Status](https://travis-ci.org/gmtprime/yggdrasil.svg?branch=master)](https://travis-ci.org/gmtprime/yggdrasil) [![Hex pm](http://img.shields.io/hexpm/v/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil) [![hex.pm downloads](https://img.shields.io/hexpm/dt/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil) [![Deps Status](https://beta.hexfaktor.org/badge/all/github/gmtprime/yggdrasil.svg)](https://beta.hexfaktor.org/github/gmtprime/yggdrasil) [![Inline docs](http://inch-ci.org/github/gmtprime/yggdrasil.svg?branch=master)](http://inch-ci.org/github/gmtprime/yggdrasil)

> *Yggdrasil* is an immense mythical tree that connects the nine worlds in
> Norse cosmology.

`Yggdrasil` manages subscriptions to channels/queues in several brokers with
the possibility to add more. Simple Redis, RabbitMQ and Postgres adapters
are implemented. Message passing is done through
[`YProcess`](https://github.com/gmtprime/y_process). `YProcess` allows to use
`Phoenix.PubPub` as a pub/sub to distribute messages between processes.

## Example using Redis

```elixir
iex(1)> channel = %Yggdrasil.Channel{channel: "redis_channel", decoder: Yggdrasil.Decoder.Default.Redis}
iex(2)> Yggdrasil.subscribe(channel)
```

Then in redis:

```
127.0.0.1:6379> PUBLISH "redis_channel" "hello"
(integer) (1)
```

And finally if you flush in your `iex` you'll see the message received
by the Elixir shell:

```elixir
iex(3> flush()
{:Y_CAST_EVENT, "redis_channel", "hello"}
:ok
```

Things to note:

  * Every message coming from a broker (Redis, RabbitMQ, Postgres) will be like:

  ```elixir
  {:Y_CAST_EVENT, channel, message}
  ```

  * The process calling `Yggdrasil.subscribe/1` will be the one that subscribes
  to the channel

## Example using `GenServer`

The previous example can be wrapped inside a `GenServer`

```elixir
defmodule Subscriber do
  use GenServer

  ###################
  # Client functions.

  def start_link(channel, opts \\ []) do
    GenServer.start_link(__MODULE__, channel, opts)
  end

  def stop(subscriber, reason \\ :normal) do
    GenServer.stop(subscriber, reason)
  end

  ######################
  # GenServer callbacks.

  def init(channel) do
    Yggdrasil.subscribe(channel)
    {:ok, channel}
  end

  def handle_info({:Y_CAST_EVENT, channel, message}, state) do
    IO.inspect %{channel: channel, message: message}
    {:noreply, state}
  end

  def terminate(_reason, channel) do
    Yggdrasil.unsubscribe(channel)
    :ok
  end
end
````

So in `iex`:

```elixir
iex(1)> channel = %Yggdrasil.Channel{channel: "redis_channel", decoder: Yggdrasil.Decoder.Default.Redis}
iex(2)> {:ok, subscriber} = Subscriber.start_link(channel)
iex(3)>
```

Again in Redis:

```
127.0.0.1:6379> PUBLISH "redis_channel" "hello"
(integer) (1)
```

And finally you'll see in your `iex` the following:

```elixir
%{channel: "redis_channel", message: "hello"}
iex(3)>
```

## Example using `YProcess`

`YProcess` is a `GenServer` wrapper with pubsub capabilities and it has
great sinergy with `Yggdrasil`. The previous example implemented with
`YProcess` would be:

```elixir
defmodule YSubscriber do
  use YProcess, backend: Yggdrasil.Backend

  ###################
  # Client functions.

  def start_link(channel, opts \\ []) do
    YProcess.start_link(__MODULE__, channel, opts)
  end

  def stop(subscriber, reason \\ :normal) do
    YProcess.stop(subscriber, reason)
  end

   #####################
   # YProcess callbacks.

   def init(channel) do
     {:join, [channel], channel}
   end

  def handle_event(channel, message, state) do
    IO.inspect %{channel: channel, message: message}
    {:noreply, state}
  end
end
```

So in `iex`:

```elixir
iex(1)> channel = %Yggdrasil.Channel{channel: "redis_channel", decoder: Yggdrasil.Decoder.Default.Redis}
iex(2)> {:ok, y_subscriber} = YSubscriber.start_link(channel)
iex(3)>
```

Again in Redis:

```
127.0.0.1:6379> PUBLISH "redis_channel" "hello"
(integer) (1)
```

And finally you'll see in your `iex` the following:

```elixir
%{channel: "redis_channel", message: "hello"}
iex(3)>
```

## Yggdrasil Channels

`Yggdrasil` channels have the name of the channel in the broker and the
name of the module of the message decoder. A decoder module also defines
which adapter should be used to connect to the channel.

```elixir
%Yggdrasil.Channel{channel: "channel", decoder: Yggdrasil.Decoder.Default.Redis}
```
The previous example will tell Yggdrasil to subscribe to the channel `"channel"`.
The decoder module `Yggdrasil.Decoder.Default.Redis` defined Redis as the broker
and does not change the message coming from Redis before sending it to the
subscribers.

### Decoders

The current `Yggdrasil` version has the following decoder modules:

  * `Yggdrasil.Decoder.Default`: Does nothing to the message and uses the
  `Yggdrasil.Adapter.Elixir`.
  * `Yggdrasil.Decoder.Default.Redis`: Does nothing to the message and uses the
  `Yggdrasil.Adapter.Redis`.
  * `Yggdrasil.Decoder.Default.RebbitMQ`: Does nothing to the message and uses the
  `Yggdrasil.Adapter.RabbitMQ`.
  * `Yggdrasil.Decoder.Default.Postgres`: Does nothing to the message and uses the
  `Yggdrasil.Adapter.Postgres`.

> For more information about adapters, see the Adapters section.

To implement a decoder is necessary to implement the `decode/2` callback for
`Yggdrasil.Decoder` behaviour, i.e. subscribe to a Redis channel `"test"` that
publishes JSON. The subscribers must receive a map instead of a string with the
JSON.

```elixir
defmodule CustomDecoder do
  use Yggdrasil.Decoder, adapter: Yggdrasil.Adapter.Redis

  def decode(_channel, message) do
    Poison.decode!(message)
  end
end
```

To subscribe to this channel, clients must use the following `Yggdrasil` channel:

```elixir
%Yggdrasil.Channel{channel: "test", decoder: CustomDecoder}
```

### Adapters

The current `Yggdrasil` version has the following adapters:

  * `Yggdrasil.Adapter.Elixir`: Message distribution using Elixir messages.
  * `Yggdrasil.Adapter.Redis`: Messages come from a Redis channel.
  * `Yggdrasil.Adapter.RabbitMQ`: Messages come from a RabbitMQ queue. A
  `channel` is a tuple that contains the exchange and the routing key:
  `{exchange, routing_key}`.
  * `Yggdrasil.Adapter.Postgres`: Messages come from the notifies of a
  PostgreSQL database.

Also the function `Yggdrasil.publish/2` is used to simulate published messages
by any of the brokers.

To implement a new adapter is necessary to use a `GenServer` or any wrapper over
`GenServer`. For more information, see the source code of any of the implemented
adapters.

## Installation

`Yggdrasil` is available as a Hex package. To install, add it to your
dependencies in your `mix.exs` file:

```elixir
def deps do
  [{:amqp_client, git: "https://github.com/jbrisbin/amqp_client.git", override: true},
   {:yggdrasil, "~> 2.0.0"}]
end
```

> Overriding `:amqp_client` dependency is necessary in order to use `Yggdrasil` with Erlang 19.

and ensure `Yggdrasil` is started before your application:

```elixir
def application do
  [applications: [:yggdrasil]]
end
```

## Configuration

`Yggdrasil` uses `YProcess` as a means to distribute the messages. So it is
necessary to provide a configuration for `YProcess` if you want to use, for
example, `Phoenix.PubSub` as your pubsub, i.e:

```elixir
use Mix.Config

config :y_process,
  backend: YProcess.Backend.PhoenixPubSub,
  name: Yggdrasil.PubSub,
  adapter: Phoenix.PubSub.PG2,
  options: [pool_size: 10]
```
by default, `YProcess` will use `YProcess.Backend.PG2` as default backend.

For `Yggdrasil`, there's only one general configuration parameter which is
the process name registry. By default, it uses `ExReg`, which is a simple but
rich process name registry. It is possible to use another one like `:gproc`.

```elixir
use Mix.Config

config :yggdrasil,
  registry: :gproc
```

Specific configuration parameters are as follows:

  * To configure `Yggdrasil` with the provided Redis adapter
  (`Yggdrasil.Adapter.Redis`):

  ```elixir
  use Mix.Config

  config :yggdrasil,
    redis: [host: "localhost",
            port: 6379,
            password: "my password"]
  ```
  The default Redis adapter uses `Redix`, so the configuration parameters have
  the same name as the ones in `Redix`. By default connects to `redis://localhost`.

  * To configure `Yggdrasil` with the provided RabbitMQ adapter
  (`Yggdrasil.Adapter.RabbitMQ`):

  ```elixir
  use Mix.Config

  config :yggdrasil,
    rabbitmq: [host: "localhost",
               port: 5672,
               username: "guest",
               password: "guest",
               virtual_host: "/"]
  ```
  The default RabbitMQ adapter uses `AMQP`, so the configuration parameters have
  the same name as the ones in `AMQP`. By default connects to
  `amqp://guest:guest@localhost/`

  * To configure `Yggdrasil` with the provided PostgreSQL adapter
  (`Yggdrasil.Adapter.Postgres`):

  ```elixir
  use Mix.Config
    postgres: [hostname: "localhost",
               port: 5432,
               username: "postgres",
               password: "postgres",
               database: "yggdrasil"]
  ```
  The default PostgreSQL adapter uses `Postgrex`, so the configuration parameters
  have the same name as the ones in `Postgrex`.

## Relevant projects used

  * [`ExReg`](https://github.com/gmtprime/exreg): rich process name registry.
  * [`YProcess`](https://github.com/gmtprime/y_process): wrapper over `GenServer` with pubsub capabilities.
  * [`Redix.PubSub`](https://github.com/whatyouhide/redix_pubsub): Redis pubsub.
  * [`AMQP`](https://github.com/pma/amqp): RabbitMQ pubsub.
  * [`Postgrex`](https://github.com/elixir-ecto/postgrex): Postgres pubsub.
  * [`Connection`](https://github.com/fishcakez/connection): wrapper over `GenServer` to handle connections.
  * [`Credo`](https://github.com/rrrene/credo): static code analysis tool for the Elixir language.
  * [`InchEx`](https://github.com/rrrene/inch_ex): Mix task that gives you hints where to improve your inline docs.

## Author

Alexander de Sousa.

## License

`Yggdrasil` is released under the MIT License. See the LICENSE file for further details.
