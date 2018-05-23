defmodule Yggdrasil.Publisher.Adapter.RedisTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Adapter.Redis

  test "publisher" do
    name = "redis_channel_2"
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
    assert {:ok, adapter} = Redis.start_link(Test)
    assert :ok = Redis.publish(adapter, pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 500
    assert :ok = Redis.stop(adapter)

    :ok = Yggdrasil.unsubscribe(sub_channel)
    assert_receive {:Y_DISCONNECTED, ^sub_channel}, 500
  end
end
