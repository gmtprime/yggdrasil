defmodule Yggdrasil.Distributor.Adapter.ElixirTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Subscriber.Adapter.Elixir, as: Basic

  test "start - stop" do
    name = UUID.uuid4()
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
    Backend.subscribe(channel)
    assert {:ok, publisher} = Publisher.start_link(channel)
    assert {:ok, adapter} = Basic.start_link(channel, publisher)
    assert :ok = Basic.stop(adapter)
    assert :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
  end

  test "distribute message" do
    name = UUID.uuid4()
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
    Backend.subscribe(channel)
    assert {:ok, publisher} = Publisher.start_link(channel)
    assert {:ok, adapter} = Basic.start_link(channel, publisher)

    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_CONNECTED, ^channel}, 500
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    assert :ok = Basic.stop(adapter)
    assert :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
    assert_receive {:Y_DISCONNECTED, ^channel}, 500
  end
end
