defmodule Yggdrasil.Publisher.Adapter.RabbitMQTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Adapter.RabbitMQ

  test "publisher" do
    name = {"amq.topic", "rabbitmq_2"}
    sub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.RabbitMQ,
      namespace: Test
    }
    :ok = Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}, 500
    pub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Publisher.Adapter.RabbitMQ,
      namespace: Test
    }
    assert {:ok, adapter} = RabbitMQ.start_link(Test)
    assert :ok = RabbitMQ.publish(adapter, pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 500
    assert :ok = RabbitMQ.stop(adapter)

    :ok = Yggdrasil.unsubscribe(sub_channel)
    assert_receive {:Y_DISCONNECTED, ^sub_channel}, 500
  end
end
