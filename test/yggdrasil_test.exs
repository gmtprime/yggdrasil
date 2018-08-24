defmodule YggdrasilTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel

  test "full subscription cycle" do
    channel = %Channel{name: UUID.uuid4()}

    assert :ok = Yggdrasil.subscribe(channel)
    assert_receive {:Y_CONNECTED, _}

    assert :ok = Yggdrasil.publish(channel, "message")
    assert_receive {:Y_EVENT, _, "message"}

    assert :ok = Yggdrasil.unsubscribe(channel)
    assert_receive {:Y_DISCONNECTED, _}
  end
end
