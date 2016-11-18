defmodule Yggdrasil.Publisher.Adapter.RedisTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Adapter.Redis

  test "publisher" do
    name = "redis_channel_2"
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
    assert {:ok, adapter} = Redis.start_link(Test)
    assert :ok = Redis.publish(adapter, pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}
    assert :ok = Redis.stop(adapter)

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end
end
