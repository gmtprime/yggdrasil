defmodule Yggdrasil.Subscriber.Adapter.RedisTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Backend
  alias Yggdrasil.Subscriber.Publisher
  alias Yggdrasil.Subscriber.Adapter
  alias Yggdrasil.Subscriber.Adapter.Redis

  test "distribute message" do
    name = UUID.uuid4()
    channel = %Channel{name: name, adapter: :redis, namespace: RedisTest}
    {:ok, channel} = Registry.get_full_channel(channel)

    Backend.subscribe(channel)
    assert {:ok, publisher} = Publisher.start_link(channel)

    assert {:ok, adapter} = Adapter.start_link(channel, publisher)
    assert_receive {:Y_CONNECTED, _}, 500

    options = Redis.redis_options(channel)
    {:ok, conn} = Redix.start_link(options)
    {:ok, 1} = Redix.command(conn, ~w(PUBLISH #{name} #{"message"}))
    Redix.stop(conn)

    assert_receive {:Y_EVENT, _, "message"}, 500

    assert :ok = Adapter.stop(adapter)
    assert_receive {:Y_DISCONNECTED, _}, 500

    assert :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
  end
end
