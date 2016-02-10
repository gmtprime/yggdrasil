defmodule Yggdrasil.RabbitMQTest do
  use ExUnit.Case, async: true
  alias Yggdrasil.Proxy, as: Proxy
  alias Yggdrasil.Proxy.Data, as: Data
  alias Yggdrasil.Util.Forwarder, as: Forwarder
  alias Yggdrasil.Messenger, as: Broker
  require Logger

  @forwarder Yggdrasil.Util.Forwarder
  @rabbitmq_broker Yggdrasil.Broker.RabbitMQ

  setup do
    Logger.remove_backend :console
    {:ok, proxy} = Proxy.start_link
    forwarder = Forwarder.set_parent @forwarder
    {:ok, %{proxy: proxy, forwarder: forwarder, channel: {"plants", "trees"}}}
  end

  test "subscribe/unsubscribe",
       %{proxy: proxy, forwarder: forwarder,
         channel: {exchange, routing_key} = channel} do
    {:ok, conn} = AMQP.Connection.open
    {:ok, publisher} = AMQP.Channel.open conn
    AMQP.Exchange.topic publisher, exchange, durable: false
    {:ok, handle} = Proxy.subscribe proxy, @rabbitmq_broker, channel
    {:ok, broker} = Broker.start_link @rabbitmq_broker,
                                      channel,
                                      proxy,
                                      forwarder
    assert_receive {:subscribed, @rabbitmq_broker, ^channel}  # From Rabbit Broker
    message = "Yggdrasil!"
    AMQP.Basic.publish publisher, exchange, routing_key, message 
    assert_receive %Data{broker: @rabbitmq_broker,
                         data: ^message,
                         channel: ^channel}  # From Proxy rerouted by Broker
    Broker.stop broker
    assert_receive {:unsubscribed, @rabbitmq_broker, ^channel}  # From Broker
    Proxy.unsubscribe proxy, handle
    AMQP.Channel.close publisher
    AMQP.Connection.close conn
  end
end
