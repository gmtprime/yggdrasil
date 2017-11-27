defmodule YggdrasilTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend

  test "subscribe - unsubscribe" do
    name = UUID.uuid4()
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
    assert :ok = Yggdrasil.subscribe(channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500
    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500
    assert :ok = Yggdrasil.unsubscribe(channel)
  end

  test "publish elixir" do
    name = UUID.uuid4()
    sub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Elixir,
      namespace: YggdrasilTest
    }
    :ok = Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}, 500
    pub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Publisher.Adapter.Elixir,
      namespace: YggdrasilTest
    }
    assert :ok = Yggdrasil.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 500

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end

  test "publish Redis" do
    name = "redis_full_test"
    sub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Redis,
      namespace: Test
    }
    :ok = Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}, 500
    pub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Publisher.Adapter.Redis,
      namespace: Test
    }
    assert :ok = Yggdrasil.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 500

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end

  test "publish RabbitMQ" do
    name = {"amq.topic", "rabbitmq_full_test"}
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
    assert :ok = Yggdrasil.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 500

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end

  test "publish RabbitMQ with headers" do
    name = {"custom.delayed_topic", "rabbitmq_headers_full_test"}
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
    options = [headers: [{"x-delay", :long, 500}]]
    assert :ok = Yggdrasil.publish(pub_channel, "message", options)
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 5_000
  end

  test "publish Postgres" do
    name = "postgres_full_test"
    sub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Postgres,
      namespace: Test
    }
    :ok = Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}, 500
    pub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Publisher.Adapter.Postgres,
      namespace: Test
    }
    assert :ok = Yggdrasil.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 500

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end
end
