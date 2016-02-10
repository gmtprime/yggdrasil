# Yggdrasil

> *Yggdrasil* is an immense mythical tree that connects the nine worlds in
> Norse cosmology.

Yggdrasil manages subscriptions to channels/queues in some broker. Simple
Redis and RabbitMQ interfaces are implemented. By default the messages are
sent to the process calling the function to subscribe to the channel.

### Starting the feed.

```
$ iex -S mix
Erlang/OTP 18 [erts-7.0] [source] [64-bit] [smp:8:8] [async-threads:10]
[kernel-poll:false]

Interactive Elixir (1.2.0) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> Yggdrasil.Feed.subscribe Yggdrasil.Feed,
...(1)>                          Yggdrasil.Broker.Redis,
...(1)>                          "trees",
...(1)>                          &(IO.puts "#{inspect &1}")
{:ok,
 %{broker: Yggdrasil.Broker.Redis, channel: "trees",
    ref: #Reference<0.0.4.895>}}
iex(2)>
```

And from `redis-cli`:

```
127.0.0.1:6379> publish "trees" "Yggdrasil"                                                              
(integer) 1
127.0.0.1:6379> publish "trees" "Yggdrasil"                                                              
(integer) 1
127.0.0.1:6379> publish "trees" "Yggdrasil"                                                              
(integer) 1
```

You'll receive in `iex`:

```
iex(2)>
%Yggdrasil.Proxy.Data{broker: Yggdrasil.Broker.Redis, data: \"Yggdrasil\", channel: \"trees\"}
%Yggdrasil.Proxy.Data{broker: Yggdrasil.Broker.Redis, data: \"Yggdrasil\", channel: \"trees\"}
%Yggdrasil.Proxy.Data{broker: Yggdrasil.Broker.Redis, data: \"Yggdrasil\", channel: \"trees\"}
iex(2)>
```

### Using the `Yggdrasil.Subscriber.Base` behaviour

The `Yggdrasil.Subscriber.Base` behaviour, defines the following callbacks:

```
#!Elixir
@doc """
Initializes the subscriber state.
"""
@callback init(args :: term) :: {:ok, state :: term} | {:error, reason :: term}

@doc """
Updates the subscriber state.
"""
@callback update_state(old_state :: term, new_state :: term) :: state :: term

@doc """
Handles the messages received from the broker. This function is called in a
separated process.
"""
@callback handle_message(message :: term, state :: term) :: :ok | :error

@doc """
Handles the termination of the subscriber server.
"""
@callback terminate(reason :: term, state :: term) :: term
```

And by default it generates the following functions:

```
#!Elixir

@doc """
Starts a subscriber.

Args:
`feed` - Feed from where it'll receive the messages.
`args` - Internal state. State of the subscriber.
`options` - Options (GenServer options).

Returns:
GenServer output.
"""
@spec start_link(feed :: pid | atom | {atom, node}, args :: term,
                 options :: term) ::
    {:ok, pid} |
    :ignore |
    {:error, {:already_started, pid} | term}

@doc """
Updates the state of the subscriber.

Args:
`server` - Subscriber pid.
`state` - New state.
"""
@spec register(server :: pid | atom | {atom, node}, state :: term) :: :ok

@doc """
Subscribes to a channel.

Args:
`server` - Subscriber pid.
`channel` - Channel name
"""
@spec subscribe(server :: pid | atom | {atom, node}, channel :: term) :: :ok

@doc """
Unsubscribes from a channel.

Args:
`server` - Subscriber pid.
`channel` - Channel name.
"""
@spec unsubscribe(server :: pid | atom | {atom, node}, channel :: term) :: :ok

@doc """
Stops the subscriber.

Args:
`server` - Subscriber pid.
`reason` - Reason to stop (default = `:normal`)
"""
@spec stop(server :: pid | atom | {atom, node}, reason :: term) :: term
```

Messages from a broker come always as the `defstruct Yggdrasil.Proxy.Data`:

```
#!Elixir
defmodule Yggdrasil.Proxy.Data do
  defstruct data: nil, channel: nil, broker: nil
  @type t :: %__MODULE__{data: term, channel: term, broker: atom}
end
```

To use this behaviour it's necessary to give a broker as argument. For example,
a subscriber that prints messages received from a Redis channel:

```
#!Elixir
defmodule Subscriber do
  use Yggdrasil.Subscriber.Base, broker: Yggdrasil.Broker.Redis
  alias Yggdrasil.Proxy.Data, as: Data

  def handle_message(%Data{channel: channel, data: message}, _state) do
    IO.puts "Received: #{inspect message} from #{inspect channel}"
    :ok
  end
end
```

To execute it:

```
iex(1)> {:ok, conn} = Subscriber.start_link(Yggdrasil.Feed)
{:ok, #PID<0.350.0>}
iex(2)> Subscriber.subscribe(conn, "trees")
:ok
iex(3)>
```
      
If you execute the following command in Redis:

```
127.0.0.1:6379> PUBLISH "trees" "Yggdrasil!"
```

You'll get:

```
Received: "Yggdrasil!" from "trees"
:ok
iex(3)>
```        

And if you unsubscribe to channel `"trees"`, `Subscriber` no longer will
receive messages from that channel:

```
iex(3)> Subscriber.unsubscribe(conn, "trees")
:ok
```        

## New brokers.

You can code new brokers better suited for your needs.

There are two ways of accomplish this.

### Using the `Yggdrasil.Broker`

This behaviour is for implementation of new brokers. You need to implement
three functions: `subscribe/2`, `unsubscribe/1` and `handle_message/2`.
For example, a broker made out of a `GenServer`:

```
#!Elixir
defmodule Broker do
  use GenServer
  use Yggdrasil.Broker

  ###################
  # Client callbacks.
 
  def subscribe(channel, callback) do
    {:ok, conn} = __MODULE__.start_link
    conn |> GenServer.cast({:subscribe, channel, callback})
    {:ok, conn}
  end


  def unsubscribe(conn), do:
    __MODULE__.stop conn


  def handle_message(_conn, :subscribed), do:
    :subscribed
  def handle_message(_conn, {:message, message}), do:
    {:message, message}
  def handle_message(_conn, _ignored), do:
    :whatever

  ###################
  # Client functions.

  def start_link() do
    GenServer.start_link __MODULE__, nil, []
  end

  def publish(broker, channel, message), do:
    GenServer.cast broker, {:publish, channel, message}

  def stop(broker), do:
    GenServer.cast broker, :stop

  ###################
  # Server callbacks.

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast(:stop, state), do:
    {:stop, :normal, state}
  def handle_cast({:subscribe, channel, callback}, state) do
    new_state = Map.put state, channel, callback
    callback.(:subscribed)
    {:noreply, new_state}
  end
  def handle_cast({:publish, channel, message}, state) do
    case Map.fetch state, channel do
      :error ->
        :ok
      {:ok, callback} ->
        callback.({:message, message})
    end
    {:noreply, state}
  end
  def handle_cast(_any, state), do:
    {:noreply, state}
```

You can now use the `Broker` with the `Subscriber`.

### Using the `Yggdrasil.Broker.GenericBroker`

This behaviour is used to modify the decoding of messages in an existent
broker.

Let's say we now want to assure we will have string messages coming
from our `Broker` and only receive messages from the broker every second
because we don't need all the published messages, we would do:

```
#!Elixir
defmodule GenericBroker do
  use Yggdrasil.Broker.GenericBroker,
      broker: Broker,
      interval: 1000 

  def decode(message) do:
    {:message, inspect(message)}
end
```

Now instead of using our `Broker`, we would use `GenericBroker` with
our `Subscriber`.

## Configuration

For the two brokers provided, you can use the following configuration file
(`config/config.exs`):

```
#!Elixir
use Mix.Config

# For Redis
config :exredis,
       host: "localhost",
       port: 6379,
       password: "MyPassword",
       reconnect: :no_reconnect,
       max_queue: :infinity

# For RabbitMQ
config :amqp,
       host: "localhost",
       port: 5672, 
       username: "guest",
       password: "guest",
       virtual_host: "/"
```

## Installation

Ensure yggdrasil is started before your application:

```
#!Elixir
def application do
  [applications: [:yggdrasil]]
end
```
