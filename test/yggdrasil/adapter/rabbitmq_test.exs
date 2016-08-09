defmodule Yggdrasil.Adapter.RabbitMQTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel

  test "rabbitmq subscriber" do
    options = Application.get_env(:yggdrasil, :rabbitmq, [])
    {:ok, conn} = AMQP.Connection.open(options)
    {:ok, chan} = AMQP.Channel.open(conn)
    exchange = UUID.uuid4()
    channel_name = UUID.uuid4()
    :ok = AMQP.Exchange.topic(chan, exchange) 

    channel = %Channel{decoder: Yggdrasil.Decoder.Default.RabbitMQ,
                       channel: {exchange, channel_name}}
    {:ok, client} = TestClient.start_link(self(), channel)
    assert_receive :ready, 200

    AMQP.Basic.publish(chan, exchange, channel_name, "message")

    assert_receive {:event, {^exchange, ^channel_name}, "message"}
    TestClient.stop(client)

    AMQP.Connection.close(conn)
  end
end
