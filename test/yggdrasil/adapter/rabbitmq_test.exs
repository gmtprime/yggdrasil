defmodule Yggdrasil.Adapter.RabbitMQTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel

  test "rabbitmq subscriber" do
    options = Application.get_env(:yggdrasil, :rabbitmq, [])
    {:ok, conn} = AMQP.Connection.open(options)
    {:ok, chan} = AMQP.Channel.open(conn)
    :ok = AMQP.Exchange.topic(chan, "rabbit_exchange") 

    channel = %Channel{decoder: Yggdrasil.Decoder.Default.RabbitMQ,
                       channel: {"rabbit_exchange", "rabbit_channel"}}
    {:ok, client} = TestClient.start_link(self(), channel)
    assert_receive :ready, 200

    AMQP.Basic.publish(chan, "rabbit_exchange", "rabbit_channel", "message")

    assert_receive {:event, {"rabbit_exchange", "rabbit_channel"}, "message"}
    TestClient.stop(client)

    AMQP.Connection.close(conn)
  end
end
