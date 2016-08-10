defmodule YggdrasilTest do
  use ExUnit.Case
  doctest Yggdrasil

  alias Yggdrasil.Channel

  setup do
    Application.ensure_started(:yggdrasil)
  end

  test "subscribe, publish and unsubscribe" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    assert :ok = Yggdrasil.subscribe(channel)
    assert :ok = Yggdrasil.publish(channel, :message)
    assert_receive {:Y_CAST_EVENT, ^ref, :message}
    assert :ok = Yggdrasil.unsubscribe(channel)
  end
end
