defmodule Yggdrasil.Subscriber.ManagerTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Settings

  @registry Settings.yggdrasil_process_registry()

  test "gets members of an unexistent channel" do
    channel = %Channel{name: UUID.uuid4()}
    state = %Manager{channel: channel}

    assert [] == Manager.get_members(state)

    :pg2.delete(channel.name)
  end

  test "gets members of a existent channel" do
    pid = self()
    channel = %Channel{name: UUID.uuid4()}
    state = %Manager{channel: channel}

    :pg2.create(channel)
    :pg2.join(channel, pid)
    assert [pid] == Manager.get_members(state)

    :pg2.delete(channel.name)
  end

  test "monitors a PID" do
    pid = self()
    cache = :ets.new(:test, [:set])
    state = %Manager{cache: cache}

    assert :ok = Manager.monitor(pid, state)
    assert [{_, ref}] = :ets.lookup(cache, pid)
    assert true = Process.demonitor(ref)
  end

  test "monitors a PID only once" do
    pid = self()
    cache = :ets.new(:test, [:set])
    state = %Manager{cache: cache}

    assert :ok = Manager.monitor(pid, state)
    assert :ok = Manager.monitor(pid, state)
    assert [{_, ref}] = :ets.lookup(cache, pid)
    assert true = Process.demonitor(ref)
  end

  test "demonitors a PID" do
    pid = self()
    cache = :ets.new(:test, [:set])
    state = %Manager{cache: cache}

    assert :ok = Manager.monitor(pid, state)
    assert :ok = Manager.demonitor(pid, state)
    assert [] = :ets.lookup(cache, pid)
  end

  test "demonitors a PID only once" do
    pid = self()
    cache = :ets.new(:test, [:set])
    state = %Manager{cache: cache}

    assert :ok = Manager.monitor(pid, state)
    assert :ok = Manager.demonitor(pid, state)
    assert :ok = Manager.demonitor(pid, state)
    assert [] = :ets.lookup(cache, pid)
  end

  test "makes a PID join a channel" do
    pid = self()
    channel = %Channel{name: UUID.uuid4()}
    cache = :ets.new(:test, [:set])
    state = %Manager{channel: channel, cache: cache}
    _ = Manager.get_members(state)

    assert :ok == Manager.join(pid, state)
    assert [pid] == Manager.get_members(state)
    assert [{_, ref}] = :ets.lookup(cache, pid)
    assert is_reference(ref)
    assert :ok = Manager.demonitor(pid, state)

    :pg2.delete(channel.name)
  end

  test "makes a list of PIDs join a channel" do
    pid = self()
    channel = %Channel{name: UUID.uuid4()}
    cache = :ets.new(:test, [:set])
    state = %Manager{channel: channel, cache: cache}
    _ = Manager.get_members(state)

    assert :ok == Manager.join([pid], state)
    assert [pid] == Manager.get_members(state)
    assert [{_, ref}] = :ets.lookup(cache, pid)
    assert is_reference(ref)
    assert :ok = Manager.demonitor(pid, state)

    :pg2.delete(channel.name)
  end

  test "makes a PID leave a channel" do
    pid = self()
    channel = %Channel{name: UUID.uuid4()}
    cache = :ets.new(:test, [:set])
    state = %Manager{channel: channel, cache: cache}
    _ = Manager.get_members(state)

    assert :ok == Manager.join(pid, state)
    assert [pid] == Manager.get_members(state)
    assert 0 = Manager.leave(pid, state)
    assert [] = :ets.lookup(cache, pid)
    assert [] == Manager.get_members(state)

    :pg2.delete(channel.name)
  end

  test "starts/stops" do
    channel = %Channel{name: UUID.uuid4()}
    assert {:ok, pid} = Manager.start_link(channel, self())
    assert :ok = Manager.stop(pid)
  end

  test "adds a PID to subscribers on start" do
    channel = %Channel{name: UUID.uuid4()}
    {:ok, pid} = Manager.start_link(channel, self())

    assert Manager.subscribed?(channel)

    Manager.stop(pid)
  end

  test "adds a PID to subscribers" do
    channel = %Channel{name: UUID.uuid4()}
    via_tuple = {:via, @registry, {Manager, channel}}
    {:ok, pid} = Manager.start_link(channel, self(), name: via_tuple)

    assert :ok = Manager.add(channel, pid)
    assert Manager.subscribed?(channel, pid)

    Manager.stop(pid)
  end

  test "removes a PID from subscribers" do
    channel = %Channel{name: UUID.uuid4()}
    via_tuple = {:via, @registry, {Manager, channel}}
    {:ok, pid} = Manager.start_link(channel, self(), name: via_tuple)

    assert :ok = Manager.add(channel, pid)
    assert Manager.subscribed?(channel, pid)
    assert :ok = Manager.remove(channel, pid)
    assert not Manager.subscribed?(channel, pid)

    Manager.stop(pid)
  end

  test "removes dead PID from subscribers" do
    channel = %Channel{name: UUID.uuid4()}
    via_tuple = {:via, @registry, {Manager, channel}}
    {:ok, pid} = Manager.start_link(channel, self(), name: via_tuple)
    dead = spawn fn -> :ok end

    assert :ok = Manager.add(channel, dead)
    assert not Manager.subscribed?(channel, dead)

    Manager.stop(pid)
  end
end
