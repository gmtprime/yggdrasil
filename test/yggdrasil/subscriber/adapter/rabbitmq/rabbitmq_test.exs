defmodule Yggdrasil.Subscriber.Adapter.RabbitMQTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ

  test "start - stop" do
    name = {"amq.topic", "rabbitmq_0"}
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.RabbitMQ,
      namespace: Test
    }
    Backend.subscribe(channel)
    assert {:ok, publisher} = Publisher.start_link(channel)
    assert {:ok, adapter} = RabbitMQ.start_link(channel, publisher)
    assert :ok = RabbitMQ.stop(adapter)
    assert :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
  end

  test "distribute message" do
    name = {"amq.topic", "rabbitmq_1"}
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.RabbitMQ,
      namespace: Test
    }
    Backend.subscribe(channel)
    {:ok, publisher} = Publisher.start_link(channel)
    {:ok, adapter} = RabbitMQ.start_link(channel, publisher)

    assert_receive {:Y_CONNECTED, ^channel}, 500
    options = RabbitMQ.rabbitmq_options(channel)
    {:ok, conn} = AMQP.Connection.open(options)
    {:ok, chan} = AMQP.Channel.open(conn)

    :ok = AMQP.Basic.publish(chan, "amq.topic", "rabbitmq_1", "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    :ok = AMQP.Connection.close(conn)
    :ok = RabbitMQ.stop(adapter)
    :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
    assert_receive {:Y_DISCONNECTED, ^channel}, 500
  end
end
