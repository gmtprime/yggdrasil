defmodule Yggdrasil.RedisTest do
  use ExUnit.Case, async: true
  alias Yggdrasil.Proxy, as: Proxy
  alias Yggdrasil.Proxy.Data, as: Data
  alias Yggdrasil.Util.Forwarder, as: Forwarder
  alias Yggdrasil.Messenger, as: Broker
  require Logger

  @forwarder Yggdrasil.Util.Forwarder
  @redis_broker Yggdrasil.Broker.Redis

  setup do
    Logger.remove_backend :console
    {:ok, proxy} = Proxy.start_link
    forwarder = Forwarder.set_parent @forwarder
    {:ok, %{proxy: proxy, forwarder: forwarder, channel: "trees"}}
  end

  test "subscribe/unsubscribe",
       %{proxy: proxy, forwarder: forwarder, channel: channel} do
    {:ok, handle} = Proxy.subscribe proxy, @redis_broker, channel
    {:ok, broker} = Broker.start_link @redis_broker, channel, proxy, forwarder
    assert_receive {:subscribed, @redis_broker, ^channel}  # From Redis Broker
    assert_receive {:broker_conn, conn}  # From Redis Broker
    message = "Yggdrasil!"
    {:ok, publisher} = Exredis.start_link
    publisher |> Exredis.Api.publish(channel, message)
    assert_receive %Data{broker: @redis_broker,
                         data: ^message,
                         channel: ^channel}  # From Proxy rerouted by Broker
    Exredis.stop publisher
    Broker.stop broker
    assert_receive {:unsubscribed, @redis_broker, ^channel}  # From Broker
    Proxy.unsubscribe proxy, handle
  end
end
