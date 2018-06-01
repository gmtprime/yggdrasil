defmodule Yggdrasil.Subscriber.Adapter.RabbitMQ.ConnectionTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Connection, as: Conn

  test "start/stop" do
    assert {:ok, pid} = Conn.start_link(Yggdrasil)
    assert :ok = Conn.stop(pid)
  end

  test "get_connection/1" do
    assert {:ok, pid} = Conn.start_link(Yggdrasil)
    assert {:ok, conn} = Conn.get_connection(pid)
    assert Process.alive?(conn.pid)
    assert :ok = Conn.stop(pid)
  end

  test "calculate_backoff/1" do
    current = :os.system_time(:millisecond)
    retries = 3
    state = %Conn{namespace: Yggdrasil, retries: retries}

    assert {backoff, new_state} = Conn.calculate_backoff(state)
    assert backoff <= 3200 && backoff >= 32
    assert new_state.retries == retries + 1
    assert new_state.backoff >= current
  end
end
