defmodule Yggdrasil.Subscriber.AdapterTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Backend
  alias Yggdrasil.Subscriber.Publisher
  alias Yggdrasil.Subscriber.Adapter

  test "start and stop" do
    {:ok, channel} = Registry.get_full_channel(%Channel{name: UUID.uuid4()})
    Backend.subscribe(channel)
    assert {:ok, publisher} = Publisher.start_link(channel)

    assert {:ok, adapter} = Adapter.start_link(channel, publisher)
    assert_receive {:Y_CONNECTED, _}, 500
    assert :ok = Adapter.stop(adapter)
    assert_receive {:Y_DISCONNECTED, _}, 500

    assert :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
  end

  test "distribute message" do
    name = UUID.uuid4()
    {:ok, channel} = Registry.get_full_channel(%Channel{name: name})
    Backend.subscribe(channel)
    assert {:ok, publisher} = Publisher.start_link(channel)

    assert {:ok, adapter} = Adapter.start_link(channel, publisher)
    assert_receive {:Y_CONNECTED, _}, 500

    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, _, "message"}, 500

    assert :ok = Adapter.stop(adapter)
    assert_receive {:Y_DISCONNECTED, _}, 500

    assert :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
  end
end
