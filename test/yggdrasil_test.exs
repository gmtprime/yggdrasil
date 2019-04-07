defmodule YggdrasilTest do
  use ExUnit.Case, async: true

  describe "full subscription cycle" do
    test ":elixir adapter" do
      {:ok, channel} = Yggdrasil.gen_channel(name: make_ref())

      assert :ok = Yggdrasil.subscribe(channel)
      assert_receive {:Y_CONNECTED, ^channel}

      assert :ok = Yggdrasil.publish(channel, "message")
      assert_receive {:Y_EVENT, ^channel, "message"}

      assert :ok = Yggdrasil.unsubscribe(channel)
      assert_receive {:Y_DISCONNECTED, ^channel}
    end

    test ":bridge adapter" do
      remote = [name: make_ref()]
      local = [name: remote, adapter: :bridge]

      assert :ok = Yggdrasil.subscribe(local)
      assert_receive {:Y_CONNECTED, _}

      assert :ok = Yggdrasil.publish(local, "message")
      assert_receive {:Y_EVENT, _, "message"}

      assert :ok = Yggdrasil.publish(remote, "message")
      assert_receive {:Y_EVENT, _, "message"}

      assert :ok = Yggdrasil.unsubscribe(local)
      assert_receive {:Y_DISCONNECTED, _}
    end
  end
end
