defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.ConnectionTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection, as: Conn

  test "start/stop" do
    assert {:ok, pid} = Conn.start_link(Yggdrasil)
    assert :ok = Conn.stop(pid)
  end

  test "open_channel/1" do
    assert :ok = Conn.subscribe(Yggdrasil)
    assert_receive {:Y_CONNECTED, channel}
    assert {:ok, pid} = Conn.start_link(Yggdrasil)
    assert_receive {:Y_EVENT, ^channel, {:connected, _}}, 1000
    assert {:ok, chan} = Conn.open_channel(pid)
    assert Process.alive?(chan.conn.pid)
    assert Process.alive?(chan.pid)
    assert :ok = Conn.stop(pid)
  end

  test "open_channel/1 twice" do
    assert :ok = Conn.subscribe(Yggdrasil)
    assert_receive {:Y_CONNECTED, channel}
    assert {:ok, pid} = Conn.start_link(Yggdrasil)
    assert_receive {:Y_EVENT, ^channel, {:connected, _}}, 1000
    assert {:ok, chan0} = Conn.open_channel(pid)
    assert {:ok, chan1} = Conn.open_channel(pid)
    assert chan0 != chan1
    assert :ok = Conn.stop(pid)
  end
end
