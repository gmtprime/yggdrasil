defmodule Yggdrasil.Distributor.BackendTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend

  test "subscribe, publish, unsubscribe" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    assert :ok = Backend.subscribe(channel)
    assert :ok = Backend.publish(channel, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}
    assert :ok = Backend.unsubscribe(channel)
  end

  test "connected broadcast" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    assert :ok = Backend.subscribe(channel)
    assert :ok = Backend.connected(channel)
    assert_receive {:Y_CONNECTED, ^channel}
    assert :ok = Backend.unsubscribe(channel)
  end

  test "connected single" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    assert :ok = Backend.subscribe(channel)
    assert :ok = Backend.connected(channel, self())
    assert_receive {:Y_CONNECTED, ^channel}
    assert :ok = Backend.unsubscribe(channel)
  end
end
