defmodule YggdrasilTest do
  use ExUnit.Case, async: true

  describe "behaviour" do

    defmodule Subscriber do
      def start_link(parent, channel) do
        Yggdrasil.start_link(__MODULE__, [parent, channel])
      end

      def stop(pid) do
        Yggdrasil.stop(pid)
      end

      def init([parent, channel]) do
        Yggdrasil.publish(parent, :init)
        {:subscribe, [channel], parent}
      end

      def handle_connect(_channel, parent) do
        Yggdrasil.publish(parent, :handle_connect)
        {:ok, parent}
      end

      def handle_event(channel, message, parent) do
        Yggdrasil.publish(parent, {:handle_event, message})
        {:unsubscribe, [channel], parent}
      end

      def handle_disconnect(_channel, parent) do
        Yggdrasil.publish(parent, :handle_disconnect)
        {:stop, :normal, parent}
      end

      def terminate(:normal, parent) do
        Yggdrasil.publish(parent, :terminate)
      end
    end

    setup do
      channel = [name: make_ref()]
      parent = [name: make_ref()]
      assert :ok = Yggdrasil.subscribe(parent)
      assert_receive {:Y_CONNECTED, _}
      {:ok, [parent: parent, channel: channel]}
    end

    test "full cycle", %{parent: parent, channel: channel} do
      {:ok, _} = Subscriber.start_link(parent, channel)
      assert_receive {:Y_EVENT, _, :init}
      assert_receive {:Y_EVENT, _, :handle_connect}

      assert :ok = Yggdrasil.publish(channel, "foo")

      assert_receive {:Y_EVENT, _, {:handle_event, "foo"}}
      assert_receive {:Y_EVENT, _, :handle_disconnect}
      assert_receive {:Y_EVENT, _, :terminate}
    end
  end

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
