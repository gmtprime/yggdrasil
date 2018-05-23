defmodule Yggdrasil.Distributor.GeneratorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Distributor.Manager
  alias Yggdrasil.Distributor.Generator

  test "start and stop distributor" do
    assert {:ok, generator} = Generator.start_link()
    assert :ok = Generator.stop(generator)
  end

  test "subscribe/unsubscribe" do
    name = UUID.uuid4()
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
    :ok = Backend.subscribe(channel)

    assert :ok = Generator.subscribe(channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500
    assert Manager.subscribed?(channel)
    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500
    assert :ok = Generator.unsubscribe(channel)
    assert_receive {:Y_DISCONNECTED, ^channel}, 500

    :ok = Backend.unsubscribe(channel)
  end
end
