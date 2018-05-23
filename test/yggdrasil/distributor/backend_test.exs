defmodule Yggdrasil.Distributor.BackendTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend

  test "subscribe, publish, unsubscribe" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    assert :ok = Backend.subscribe(channel)
    assert :ok = Backend.publish(channel, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500
    assert :ok = Backend.unsubscribe(channel)
  end

  test "connected broadcast" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    assert :ok = Backend.subscribe(channel)
    assert :ok = Backend.connected(channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500
    assert :ok = Backend.unsubscribe(channel)
  end

  test "connected single" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    assert :ok = Backend.subscribe(channel)
    assert :ok = Backend.connected(channel, self())
    assert_receive {:Y_CONNECTED, ^channel}, 500
    assert :ok = Backend.unsubscribe(channel)
  end

  test "disconnected broadcast" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    assert :ok = Backend.subscribe(channel)
    assert :ok = Backend.disconnected(channel)
    assert_receive {:Y_DISCONNECTED, ^channel}, 500
    assert :ok = Backend.unsubscribe(channel)
  end

  test "disconnected single" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    assert :ok = Backend.subscribe(channel)
    assert :ok = Backend.disconnected(channel, self())
    assert_receive {:Y_DISCONNECTED, ^channel}, 500
    assert :ok = Backend.unsubscribe(channel)
  end
end
