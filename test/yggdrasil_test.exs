defmodule YggdrasilTest do
  use ExUnit.Case, async: true

  test "full subscription cycle" do
    {:ok, channel} = Yggdrasil.gen_channel(name: make_ref())

    assert :ok = Yggdrasil.subscribe(channel)
    assert_receive {:Y_CONNECTED, ^channel}

    assert :ok = Yggdrasil.publish(channel, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}

    assert :ok = Yggdrasil.unsubscribe(channel)
    assert_receive {:Y_DISCONNECTED, ^channel}
  end
end
