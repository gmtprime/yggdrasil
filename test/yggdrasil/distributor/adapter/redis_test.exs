defmodule Yggdrasil.Distributor.Adapter.RedisTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Adapter.Redis

  test "start - stop" do
    name = "redis_channel_0"
    channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Redis,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    Backend.subscribe(channel)
    assert {:ok, publisher} = Publisher.start_link(channel)
    assert {:ok, adapter} = Redis.start_link(channel, publisher)
    assert :ok = Redis.stop(adapter)
    assert :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
  end

  test "distribute message" do
    name = "redis_channel_1"
    channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Redis,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    Backend.subscribe(channel)
    {:ok, publisher} = Publisher.start_link(channel)
    {:ok, adapter} = Redis.start_link(channel, publisher)

    assert_receive {:Y_CONNECTED, ^channel}
    options = Redis.redis_options(channel)
    {:ok, conn} = Redix.start_link(options)
    {:ok, 1} = Redix.command(conn, ~w(PUBLISH #{name} #{"message"}))
    Redix.stop(conn)
    assert_receive {:Y_EVENT, ^channel, "message"}

    :ok = Redis.stop(adapter)
    :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
  end
end
