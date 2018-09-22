defmodule Yggdrasil.Subscriber.ManagerTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Settings
  alias Yggdrasil.Subscriber.Manager

  @registry Settings.yggdrasil_process_registry()

  describe "join/2" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      cache = :ets.new(:test, [:set])

      :pg2.create({:connected, channel})
      :pg2.create({:disconnected, channel})

      on_exit fn ->
        :pg2.delete({:connected, channel})
        :pg2.delete({:disconnected, channel})
      end

      {:ok, %{channel: channel, cache: cache}}
    end

    test "joins to connected group when connected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :connected,
        cache: cache
      }

      name = {:connected, channel}
      pid = self()

      assert :ok = Manager.join([pid], state)
      assert_receive {:Y_CONNECTED, ^channel}
      assert pid in :pg2.get_members(name)
      assert [{^pid, reference}] = :ets.lookup(cache, pid)
      assert is_reference(reference)
    end

    test "joins once when connected", %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :connected,
        cache: cache
      }

      pid = self()

      assert :ok = Manager.join([pid], state)
      assert :ok = Manager.join([pid], state)

      assert [{^pid, _}] = :ets.lookup(cache, pid)
    end

    test "joins to disconnected group when disconnected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :disconnected,
        cache: cache
      }

      name = {:disconnected, channel}
      pid = self()

      assert :ok = Manager.join([pid], state)
      assert pid in :pg2.get_members(name)
      assert [{^pid, reference}] = :ets.lookup(cache, pid)
      assert is_reference(reference)
    end

    test "joins once when disconnected", %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :disconnected,
        cache: cache
      }

      pid = self()

      assert :ok = Manager.join([pid], state)
      assert :ok = Manager.join([pid], state)

      assert [{^pid, _}] = :ets.lookup(cache, pid)
    end
  end

  describe "leave/2" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      cache = :ets.new(:test, [:set])

      :pg2.create({:connected, channel})
      :pg2.create({:disconnected, channel})

      on_exit fn ->
        :pg2.delete({:connected, channel})
        :pg2.delete({:disconnected, channel})
      end

      {:ok, %{channel: channel, cache: cache}}
    end

    test "leaves from connected group when connected",
        %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :connected,
        cache: cache
      }
      name = {:connected, channel}
      pid = self()
      :ok = Manager.join([pid], state)

      assert :ok = Manager.leave([pid], state)
      assert_receive {:Y_DISCONNECTED, ^channel}
      assert not (pid in :pg2.get_members(name))
      assert [] = :ets.lookup(cache, pid)
    end

    test "leaves from disconnected group when disconnected",
        %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :disconnected,
        cache: cache
      }
      name = {:disconnected, channel}
      pid = self()
      :ok = Manager.join([self()], state)

      assert :ok = Manager.leave([pid], state)
      assert not (pid in :pg2.get_members(name))
      assert [] = :ets.lookup(cache, pid)
    end
  end

  describe "monitor/2" do
    setup do
      cache = :ets.new(:test, [:set])

      {:ok, %{cache: cache}}
    end

    test "monitors a process", %{cache: cache} do
      state = %Manager{cache: cache}
      pid = self()

      assert :ok = Manager.monitor(pid, state)
      assert [{^pid, _}] = :ets.lookup(cache, pid)
    end

    test "monitors a process once", %{cache: cache} do
      state = %Manager{cache: cache}
      pid = self()
      :ok = Manager.monitor(pid, state)
      [{^pid, reference}] = :ets.lookup(cache, pid)

      assert :ok = Manager.monitor(pid, state)
      assert [{^pid, ^reference}] = :ets.lookup(cache, pid)
    end
  end

  describe "demonitor/2" do
    setup do
      cache = :ets.new(:test, [:set])
      state = %Manager{cache: cache}
      pid = self()
      :ok = Manager.monitor(pid, state)
      assert [{^pid, _}] = :ets.lookup(cache, pid)

      {:ok, %{cache: cache, state: state}}
    end

    test "demonitors a process", %{cache: cache, state: state} do
      pid = self()

      assert :ok = Manager.demonitor(pid, state)
      assert [] = :ets.lookup(cache, pid)
    end

    test "demonitors a process once", %{cache: cache, state: state} do
      pid = self()
      :ok = Manager.demonitor(pid, state)
      assert :ok = Manager.demonitor(pid, state)
      assert [] = :ets.lookup(cache, pid)
    end
  end

  describe "do_connected/1" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      cache = :ets.new(:test, [:set])
      state = %Manager{
        channel: channel,
        status: :disconnected,
        cache: cache
      }

      :pg2.create({:connected, channel})
      :pg2.create({:disconnected, channel})

      on_exit fn ->
        :pg2.delete({:connected, channel})
        :pg2.delete({:disconnected, channel})
      end

      :ok = Manager.join([self()], state)
      {:ok, %{channel: channel, state: state}}
    end

    test "changes pid from disconnected to connected",
         %{channel: channel, state: state} do
      pid = self()
      assert {:ok, %Manager{status: :connected}} = Manager.do_connected(state)
      assert_receive {:Y_CONNECTED, ^channel}
      name = {:disconnected, channel}
      assert not (pid in :pg2.get_members(name))
      name = {:connected, channel}
      assert pid in :pg2.get_members(name)
    end
  end

  describe "do_disconnected/1" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      cache = :ets.new(:test, [:set])
      state = %Manager{
        channel: channel,
        status: :connected,
        cache: cache
      }

      :pg2.create({:connected, channel})
      :pg2.create({:disconnected, channel})

      on_exit fn ->
        :pg2.delete({:connected, channel})
        :pg2.delete({:disconnected, channel})
      end

      :ok = Manager.join([self()], state)
      assert_receive {:Y_CONNECTED, ^channel}
      {:ok, %{channel: channel, state: state}}
    end

    test "changes pid from disconnected to connected",
         %{channel: channel, state: state} do
      pid = self()
      assert {:ok, %Manager{status: :disconnected}} =
             Manager.do_disconnected(state)
      assert_receive {:Y_DISCONNECTED, ^channel}
      name = {:connected, channel}
      assert not (pid in :pg2.get_members(name))
      name = {:disconnected, channel}
      assert pid in :pg2.get_members(name)
    end
  end

  describe "check_subscribers/1" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      cache = :ets.new(:test, [:set])

      :pg2.create({:connected, channel})
      :pg2.create({:disconnected, channel})

      on_exit fn ->
        :pg2.delete({:connected, channel})
        :pg2.delete({:disconnected, channel})
      end

      {:ok, %{channel: channel, cache: cache}}
    end

    test "when there is no subscribers and is connected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :connected,
        cache: cache
      }

      assert :stop = Manager.check_subscribers(state)
    end

    test "when there are subscribers and is connected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :connected,
        cache: cache
      }
      assert :ok = Manager.join([self()], state)
      assert :ok = Manager.check_subscribers(state)
    end

    test "when there is no subscribers and is disconnected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :disconnected,
        cache: cache
      }

      assert :stop = Manager.check_subscribers(state)
    end

    test "when there are subscribers and is disconnected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :disconnected,
        cache: cache
      }
      assert :ok = Manager.join([self()], state)
      assert :ok = Manager.check_subscribers(state)
    end
  end

  describe "subscribed?/3" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      cache = :ets.new(:test, [:set])

      :pg2.create({:connected, channel})
      :pg2.create({:disconnected, channel})

      on_exit fn ->
        :pg2.delete({:connected, channel})
        :pg2.delete({:disconnected, channel})
      end

      {:ok, %{channel: channel, cache: cache}}
    end

    test "when the subscribers are disconnected and the check is disconnected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :disconnected,
        cache: cache
      }
      pid = self()
      assert :ok = Manager.join([pid], state)
      assert true == Manager.subscribed?(:disconnected, channel, pid)
    end

    test "when the subscribers are disconnected and the check is connected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :disconnected,
        cache: cache
      }
      pid = self()
      assert :ok = Manager.join([pid], state)
      assert false == Manager.subscribed?(:connected, channel, pid)
    end

    test "when the subscribers are connected and the check is connected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :connected,
        cache: cache
      }
      pid = self()
      assert :ok = Manager.join([pid], state)
      assert_receive {:Y_CONNECTED, ^channel}
      assert true == Manager.subscribed?(:connected, channel, pid)
    end

    test "when the subscribers are connected and the check is disconnected",
         %{channel: channel, cache: cache} do
      state = %Manager{
        channel: channel,
        status: :connected,
        cache: cache
      }
      pid = self()
      assert :ok = Manager.join([pid], state)
      assert_receive {:Y_CONNECTED, ^channel}
      assert false == Manager.subscribed?(:disconnected, channel, pid)
    end
  end

  describe "start/stop" do
    test "starts and stops a manager" do
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      assert {:ok, pid} = Manager.start_link(channel)
      assert :ok = Manager.stop(pid)
    end
  end

  describe "add/2" do
    setup do
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      via_tuple = {:via, @registry, {Manager, channel}}
      {:ok, _} = Manager.start_link(channel, name: via_tuple)
      {:ok, %{channel: channel}}
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
  end

  describe "remove/2" do
    setup do
      pid = self()
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      via_tuple = {:via, @registry, {Manager, channel}}
      {:ok, _} = Manager.start_link(channel, name: via_tuple)
      :ok = Manager.add(channel, pid)
      {:ok, %{channel: channel}}
    end

    test "removes a pid from subscribers when disconnected",
         %{channel: channel} do
      pid = self()
      :ok = Manager.remove(channel, pid)
      assert false == Manager.subscribed?(:disconnected, channel, pid)
    end

    test "removes a pid from subscribers when connected",
         %{channel: channel} do
      pid = self()
      :ok = Manager.connected(channel)
      assert_receive {:Y_CONNECTED, channel}
      :ok = Manager.remove(channel, pid)
      assert_receive {:Y_DISCONNECTED, channel}
      assert false == Manager.subscribed?(:connected, channel, pid)
    end
  end

  describe "connected/1" do
    setup do
      pid = self()
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      via_tuple = {:via, @registry, {Manager, channel}}
      {:ok, _} = Manager.start_link(channel, name: via_tuple)
      :ok = Manager.add(channel, pid)
      {:ok, %{channel: channel}}
    end

    test "connects subscribers", %{channel: channel} do
      pid = self()
      assert :ok = Manager.connected(channel)
      assert_receive {:Y_CONNECTED, ^channel}
      assert false == Manager.subscribed?(:disconnected, channel, pid)
      assert true == Manager.subscribed?(:connected, channel, pid)
    end
  end

  describe "disconnected/1" do
    setup do
      pid = self()
      {:ok, channel} = Yggdrasil.gen_channel(name: UUID.uuid4())
      via_tuple = {:via, @registry, {Manager, channel}}
      {:ok, _} = Manager.start_link(channel, name: via_tuple)
      :ok = Manager.add(channel, pid)
      :ok = Manager.connected(channel)
      assert_receive {:Y_CONNECTED, ^channel}
      {:ok, %{channel: channel}}
    end

    test "disconnects subscribers", %{channel: channel} do
      pid = self()
      assert true == Manager.subscribed?(:connected, channel, pid)
      assert :ok = Manager.disconnected(channel)
      assert_receive {:Y_DISCONNECTED, ^channel}
      assert true == Manager.subscribed?(:disconnected, channel, pid)
      assert false == Manager.subscribed?(:connected, channel, pid)
    end
  end
end
