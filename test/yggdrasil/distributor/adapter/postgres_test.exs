defmodule Yggdrasil.Distributor.Adapter.PostgresTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Adapter.Postgres

  test "start - stop" do
    name = "postgres_0"
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Distributor.Adapter.Postgres,
      namespace: Test
    }
    Backend.subscribe(channel)
    assert {:ok, publisher} = Publisher.start_link(channel)
    assert {:ok, adapter} = Postgres.start_link(channel, publisher)
    assert :ok = Postgres.stop(adapter)
    assert :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
  end

  test "distribute message" do
    name = "postgres_1"
    channel = %Channel{
      name: name,
      adapter: Yggdrasil.Distributor.Adapter.Postgres,
      namespace: Test
    }
    Backend.subscribe(channel)
    {:ok, publisher} = Publisher.start_link(channel)
    {:ok, adapter} = Postgres.start_link(channel, publisher)

    assert_receive {:Y_CONNECTED, ^channel}, 500
    options = Postgres.postgres_options(channel)
    {:ok, conn} = Postgrex.start_link(options)
    {:ok, _} = Postgrex.query(conn, "NOTIFY #{name}, 'message'", [])
    assert_receive {:Y_EVENT, ^channel, "message"}, 500
    GenServer.stop(conn)

    :ok = Postgres.stop(adapter)
    :ok = Publisher.stop(publisher)
    Backend.unsubscribe(channel)
  end
end
