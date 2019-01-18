defmodule Yggdrasil do
  @moduledoc """
  [![Build Status](https://travis-ci.org/gmtprime/yggdrasil.svg?branch=master)](https://travis-ci.org/gmtprime/yggdrasil) [![Hex pm](http://img.shields.io/hexpm/v/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil) [![hex.pm downloads](https://img.shields.io/hexpm/dt/yggdrasil.svg?style=flat)](https://hex.pm/packages/yggdrasil)

  > *Yggdrasil* is an immense mythical tree that connects the nine worlds in
  > Norse cosmology.

  `Yggdrasil` is an agnostic publisher/subscriber. Some of the available adapters
  are the following:

    * [Redis](https://github.com/gmtprime/yggdrasil_redis)
    (adapter's name `:redis`).
    * [RabbitMQ](https://github.com/gmtprime/yggdrasil_rabbitmq)
    (adapter's name `:rabbitmq`).
    * [PostgreSQL](https://github.com/gmtprime/yggdrasil_postgres)
    (adapter's name `:postgres`).
    * [Ethereum](https://github.com/etherharvest/yggdrasil_ethereum)
    (adapter's name `:ethereum`).
    * [GraphQL](https://github.com/etherharvest/yggdrasil_graphql)
    (adapter's name `:graphql`).

  For more information on how to use them, check the respective repository.

  ## Small Example

  The following example uses the Elixir distribution to send the messages:

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{name: "channel"}
  iex(2)> Yggdrasil.subscribe(channel)
  iex(3)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{(...)}}
  ```

  and to publish a for the subscribers:

  ```elixir
  iex(4)> Yggdrasil.publish(channel, "message")
  iex(5)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{(...)}, "message"}
  ```

  When the subscriber wants to stop receiving messages, then it can unsubscribe
  from the channel:

  ```elixir
  iex(6)> Yggdrasil.unsubscribe(channel)
  iex(7)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{(...)}}
  ```

  ## Channels

  The struct `%Yggdrasil.Channel{}` is used for subscription and message
  publishing e.g:

  ```elixir
  %Yggdrasil.Channel{
    name: term(),        # Depends on the adapter.
    adapter: atom(),     # Adapter's name.
    transformer: atom(), # Transformer's name.
    backend: atom(),     # Backend's name.
    namespace: atom()    # Adapter's configuration namespace.
  }
  ```

  ## Adapters

  An adapter is a process that connects to a service and distributes its messages
  among the subscribers of a channel. The following repositories have some of the
  available adapters:

    * [RabbitMQ adapter](https://github.com/gmtprime/yggdrasil_rabbitmq):
    Fault-tolerant RabbitMQ adapter that handles exchange subscriptions and
    message distribution among subscribers. The name of the adapter is
    `:rabbitmq`.
    * [Redis adapter](https://github.com/gmtprime/yggdrasil_redis):
    Fault-tolerant Redis adapter that handles channel subscriptions and
    message distribution among subscribers. The name of the adapter is `:redis`.
    * [PostgreSQL adapter](https://github.com/gmtprime/yggdrasil_postgres):
    Fault-tolerant Postgres adapter that handles channel subscriptions and
    message distribution among subscribers. The name of the adapter is
    `:postgres`.
    * [Ethereum adapter](https://github.com/etherharvest/yggdrasil_ethereum):
    Fault-tolerant Ethereum adapter that handles channel subscriptions to
    Solidity contracts. The name of the adapter is `:ethereum`.
    * [GraphQL adapter](https://github.com/etherharvest/yggdrasil_graphql):
    Fault-tolerant adapter that bridges GraphQL subscriptions with Yggdrasil
    subscriptions in any adapter. The name of the adapter is `:graphql`.

  For more information on how to use them, check the corresponding repository
  documentation.

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
  by default in `:elixir` adapter and the previously mentioned adapters
  `:rabbitmq`, `:redis` and `:postgres`.

  The messages received by the subscribers when using `:default` backend are:

    * `{:Y_CONNECTED, %Yggdrasil.Channel{(...)}}` when the connection with the
    adapter is established.
    * `{:Y_EVENT, %Yggdrasil.Channel{(...)}, term()}` when a message is received
    from the adapter.
    * `{:Y_DISCONNECTED, %Yggdrasil.Channel{(...)}}` when the connection with the
    adapter is finished due to disconnection or unsubscription.

  ## Configuration

  `Yggdrasil` works out of the box with no special configuration at all. However,
  it is possible to configure the publisher. `Yggdrasil` uses `Phoenix.PubSub`
  for message distribution and the following are the available options:

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
      `[size: 5, max_overflow: 10]`).
    * `registry` - Process name registry (defaults to`ExReg`).

  For more information about configuration using OS environment variables check
  the module `Yggdrasil.Settings`.

  ## Installation

  `Yggdrasil` is available as a Hex package. To install, add it to your
  dependencies in your `mix.exs` file:

  ```elixir
  def deps do
    [{:yggdrasil, "~> 4.1"}]
  end
  ```
  """
  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher
  alias Yggdrasil.Publisher.Generator, as: PublisherGen
  alias Yggdrasil.Registry, as: Reg
  alias Yggdrasil.Subscriber.Generator, as: SubscriberGen

  ######################
  # Subscriber functions

  @doc """
  Subscribes to a `channel`.
  """
  @spec subscribe(map() | Keyword.t() | Channel.t()) :: :ok | {:error, term()}
  def subscribe(channel)

  def subscribe(channel) do
    with {:ok, full_channel} <- gen_channel(channel),
         :ok <- Backend.subscribe(full_channel) do
      SubscriberGen.subscribe(full_channel)
    end
  end

  @doc """
  Unsubscribes from a `channel`.
  """
  @spec unsubscribe(map() | Keyword.t() | Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(channel)

  def unsubscribe(channel) do
    with {:ok, full_channel} <- gen_channel(channel),
         :ok <- Backend.unsubscribe(full_channel) do
      SubscriberGen.unsubscribe(full_channel)
    end
  end

  #####################
  # Publisher functions

  @doc """
  Publishes a `message` in a `channel` with some optional `options`.
  """
  @spec publish(map() | Keyword.t() | Channel.t(), term()) ::
          :ok | {:error, term()}
  @spec publish(map() | Keyword.t() | Channel.t(), term(), Keyword.t()) ::
          :ok | {:error, term()}
  def publish(channel, message, options \\ [])

  def publish(channel, message, options) do
    with {:ok, full_channel} <- gen_channel(channel),
         {:ok, _} <- PublisherGen.start_publisher(PublisherGen, full_channel) do
      Publisher.publish(full_channel, message, options)
    end
  end

  ###################
  # Channel functions

  @doc """
  Creates a channel from `data` where data is a map or a `Keyword` list.
  """
  @spec gen_channel(map() | Keyword.t() | Channel.t()) ::
          {:ok, Channel.t()} | {:error, term()}
  def gen_channel(data)

  def gen_channel(%Channel{} = channel) do
    Reg.get_full_channel(channel)
  end

  def gen_channel(data) when is_list(data) or is_map(data) do
    Channel
    |> struct(data)
    |> gen_channel()
  end

  def gen_channel(_) do
    {:error, "Bad channel"}
  end
end
