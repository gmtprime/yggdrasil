defmodule Yggdrasil.Subscriber.Adapter.RabbitMQTest do
  use ExUnit.Case, async: true


  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Backend
  alias Yggdrasil.Subscriber.Publisher
  alias Yggdrasil.Subscriber.Adapter
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ

  test "distribute message" do
    routing = "t#{UUID.uuid4() |> :erlang.phash2() |> to_string()}"
    name = {"amq.topic", routing}
    channel = %Channel{name: name, adapter: :rabbitmq, namespace: RabbitMQTest}
    {:ok, channel} = Registry.get_full_channel(channel)

    Backend.subscribe(channel)
    assert {:ok, publisher} = Publisher.start_link(channel)

    assert {:ok, adapter} = Adapter.start_link(channel, publisher)
    assert_receive {:Y_CONNECTED, _}, 500

    options = RabbitMQ.rabbitmq_options(channel)
    {:ok, conn} = AMQP.Connection.open(options)
    {:ok, chan} = AMQP.Channel.open(conn)
    :ok = AMQP.Basic.publish(chan, "amq.topic", routing, "message")
    :ok = AMQP.Connection.close(conn)

    assert_receive {:Y_EVENT, _, "message"}, 500

    assert :ok = Adapter.stop(adapter)
    assert_receive {:Y_DISCONNECTED, _}, 500
  end
end
