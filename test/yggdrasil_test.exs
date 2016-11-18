defmodule YggdrasilTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend

  test "subscribe - unsubscribe" do
    name = UUID.uuid4()
    channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name
    }
    assert :ok = Yggdrasil.subscribe(channel)
    assert_receive {:Y_CONNECTED, ^channel}
    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}
    assert :ok = Yggdrasil.unsubscribe(channel)
  end

  test "publish elixir" do
    name = UUID.uuid4()
    sub_channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: YggdrasilTest
    }
    :ok = Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}
    pub_channel = %Channel{
      adapter: Yggdrasil.Publisher.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: YggdrasilTest
    }
    assert :ok = Yggdrasil.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end

  test "publish Redis" do
    name = "redis_full_test"
    sub_channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Redis,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    :ok = Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}
    pub_channel = %Channel{
      adapter: Yggdrasil.Publisher.Adapter.Redis,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    assert :ok = Yggdrasil.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end

  test "publish RabbitMQ" do
    name = {"amq.topic", "rabbitmq_full_test"}
    sub_channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.RabbitMQ,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    :ok = Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}
    pub_channel = %Channel{
      adapter: Yggdrasil.Publisher.Adapter.RabbitMQ,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    assert :ok = Yggdrasil.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end

  test "publish Postgres" do
    name = "postgres_full_test"
    sub_channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Postgres,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    :ok = Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}
    pub_channel = %Channel{
      adapter: Yggdrasil.Publisher.Adapter.Postgres,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    assert :ok = Yggdrasil.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end
end
