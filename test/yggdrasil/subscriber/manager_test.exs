defmodule Yggdrasil.Subscriber.ManagerTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Subscriber.Manager

  describe "start/stop" do
    test "starts and stops a manager" do
      {:ok, channel} = Yggdrasil.gen_channel(name: make_ref())
      assert {:ok, pid} = Manager.start_link(channel, self())
      assert :ok = Manager.stop(pid)
    end
  end

  describe "add/2" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: make_ref())

      via_tuple = ExReg.local({Manager, channel})
      first_pid = spawn(fn -> :timer.sleep(10_000) end)
      {:ok, _} = Manager.start_link(channel, first_pid, name: via_tuple)

      {:ok, channel: channel}
    end

    test "adds a pid to subscribers", %{channel: channel} do
      pid = self()

      :ok = Manager.add(channel, pid)
      assert Manager.subscribed?(:disconnected, channel, pid)

      :ok = Manager.connected(channel)
      assert_receive {:Y_CONNECTED, ^channel}

      assert Manager.subscribed?(:connected, channel, pid)
    end

    test "does not add a subscriber twice", %{channel: channel} do
      pid = self()

      :ok = Manager.add(channel, pid)
      :ok = Manager.add(channel, pid)

      :ok = Manager.connected(channel)
      assert_receive {:Y_CONNECTED, ^channel}

      assert Manager.subscribed?(:connected, channel, pid)
    end

    test "monitors subscriber", %{channel: channel} do
      pid = self()
      :ok = Manager.add(channel, pid)

      via_tuple = ExReg.local({Manager, channel})
      %Manager{cache: cache} = :sys.get_state(via_tuple)

      assert [{^pid, reference} | _] = :ets.lookup(cache, pid)
      assert is_reference(reference)
    end
  end

  describe "remove/2" do
    setup do
      pid = self()
      {:ok, channel} = Yggdrasil.gen_channel(name: make_ref())
      via_tuple = ExReg.local({Manager, channel})
      {:ok, _} = Manager.start_link(channel, pid, name: via_tuple)

      {:ok, channel: channel, pid: pid}
    end

    test "removes a pid from subscribers when disconnected", %{
      channel: channel
    } do
      :ok = Manager.remove(channel, self())
      assert false == Manager.subscribed?(:disconnected, channel, self())
    end

    test "removes a pid from subscribers when connected", %{
      channel: channel
    } do
      :ok = Manager.connected(channel)
      assert_receive {:Y_CONNECTED, channel}

      :ok = Manager.remove(channel, self())
      assert_receive {:Y_DISCONNECTED, channel}

      assert false == Manager.subscribed?(:connected, channel, self())
    end

    test "removes monitor from subscriber", %{channel: channel} do
      dummy = spawn(fn -> :timer.sleep(10_000) end)
      :ok = Manager.add(channel, dummy)

      via_tuple = ExReg.local({Manager, channel})
      %Manager{cache: cache} = :sys.get_state(via_tuple)

      :ok = Manager.remove(channel, self())
      assert false == Manager.subscribed?(:disconnected, channel, self())

      assert [] = :ets.lookup(cache, self())
    end
  end

  describe "connected/1" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: make_ref())
      via_tuple = ExReg.local({Manager, channel})
      {:ok, _} = Manager.start_link(channel, self(), name: via_tuple)

      {:ok, channel: channel}
    end

    test "connects subscribers", %{channel: channel} do
      assert :ok = Manager.connected(channel)
      assert_receive {:Y_CONNECTED, ^channel}

      assert false == Manager.subscribed?(:disconnected, channel, self())
      assert true == Manager.subscribed?(:connected, channel, self())
    end
  end

  describe "disconnected/1" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: make_ref())
      via_tuple = ExReg.local({Manager, channel})
      {:ok, _} = Manager.start_link(channel, self(), name: via_tuple)

      :ok = Manager.connected(channel)
      assert_receive {:Y_CONNECTED, ^channel}

      {:ok, channel: channel}
    end

    test "disconnects subscribers", %{channel: channel} do
      assert true == Manager.subscribed?(:connected, channel, self())

      assert :ok = Manager.disconnected(channel)
      assert_receive {:Y_DISCONNECTED, ^channel}

      assert true == Manager.subscribed?(:disconnected, channel, self())
      assert false == Manager.subscribed?(:connected, channel, self())
    end
  end
end
