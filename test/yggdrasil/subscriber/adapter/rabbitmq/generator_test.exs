defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.GeneratorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator
  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection, as: Conn

  test "connect and open_channel" do
    assert :ok = Conn.subscribe(Yggdrasil)
    assert_receive {:Y_CONNECTED, channel}
    assert {:ok, pid} = Generator.start_link()
    assert {:ok, _} = Generator.connect(pid, Yggdrasil)
    assert_receive {:Y_EVENT, ^channel, {:connected, _}}, 500
    assert {:ok, chan} = Generator.open_channel(Yggdrasil)
    assert Process.alive?(chan.conn.pid)
    assert Process.alive?(chan.pid)
    assert :ok = Generator.stop(pid)
  end
end
