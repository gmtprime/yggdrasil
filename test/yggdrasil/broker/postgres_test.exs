defmodule Yggdrasil.Broker.PostgresTest do
  use ExUnit.Case, async: true
  alias Yggdrasil.Proxy, as: Proxy
  alias Yggdrasil.Proxy.Data, as: Data
  alias Yggdrasil.Util.Forwarder, as: Forwarder
  alias Yggdrasil.Messenger, as: Broker
  require Logger

  @forwarder Yggdrasil.Util.Forwarder
  @postgres_broker Yggdrasil.Broker.Postgres

  setup do
    Logger.remove_backend :console
    {:ok, proxy} = Proxy.start_link
    forwarder = Forwarder.set_parent @forwarder
    {:ok, %{proxy: proxy, forwarder: forwarder, channel: "trees"}}
  end

  test "subscribe/unsubscribe",
       %{proxy: proxy, forwarder: forwarder, channel: channel} do
    {:ok, handle} = Proxy.subscribe(proxy, @postgres_broker, channel)
    {:ok, broker} = Broker.start_link(@postgres_broker, channel, proxy,
                                      forwarder)
    assert_receive {:subscribed, @postgres_broker, ^channel}  # From PG Broker
    assert_receive {:broker_conn, conn}  # From PG Broker
    message = "Yggdrasil!"

    config = Application.get_env(:postgrex, Yggdrasil.Repo)
    {:ok, conn} = Postgrex.start_link(config)
    Postgrex.query(conn, "NOTIFY #{channel}, '#{message}'", [])
    assert_receive %Data{broker: @postgres_broker,
                         data: ^message,
                         channel: ^channel}  # From Proxy rerouted by Broker
    GenServer.stop(conn)
    Broker.stop broker
    assert_receive {:unsubscribed, @postgres_broker, ^channel}  # From Broker
    Proxy.unsubscribe proxy, handle
  end
end
