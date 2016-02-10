defmodule Yggdrasil.MessengerTest do
  use ExUnit.Case, async: true
  alias Yggdrasil.Proxy, as: Proxy
  alias Yggdrasil.Proxy.Data, as: Data
  alias Yggdrasil.Util.Forwarder, as: Forwarder
  alias Yggdrasil.Messenger, as: Broker
  require Logger

  @forwarder Yggdrasil.Util.Forwarder
  @test_broker Yggdrasil.Test.TestBroker
  @test_timeout_broker Yggdrasil.Test.TestTimeoutBroker

  setup do
    Logger.remove_backend :console
    {:ok, proxy} = Proxy.start_link
    forwarder = Forwarder.set_parent @forwarder
    {:ok, %{proxy: proxy, forwarder: forwarder}}
  end

  test "subscribe/unsubscribe",
       %{proxy: proxy, forwarder: forwarder} do
    channel = :channel
    {:ok, handle} = Proxy.subscribe proxy, @test_broker, channel
    {:ok, broker} = Broker.start_link @test_broker, channel, proxy, forwarder
    assert_receive {:subscribed, @test_broker, ^channel}  # From Broker
    assert_receive {:broker_conn, conn}  # From Broker
    @test_broker.publish conn, channel, :test 
    assert_receive %Data{broker: @test_broker,
                         data: :test,
                         channel: ^channel}  # From Proxy rerouted by Broker
    Broker.stop broker
    assert_receive {:unsubscribed, @test_broker, ^channel}  # From Broker
    Proxy.unsubscribe proxy, handle
  end

  test "subscribe/unsubscribe with timeout",
       %{proxy: proxy, forwarder: forwarder} do
    channel = :channel_timeout
    {:ok, handle} = Proxy.subscribe proxy, @test_broker, channel
    {:ok, broker} = Broker.start_link @test_broker, channel, proxy,
                                      forwarder
    assert_receive {:subscribed, @test_broker, ^channel}  # From Broker
    assert_receive {:broker_conn, conn}  # From Broker

    @test_broker.publish conn, channel, :test 
    assert_receive %Data{broker: @test_broker,
                         data: :test,
                         channel: ^channel}  # From Proxy rerouted by Broker

    @test_broker.publish conn, channel, :test 
    assert_receive %Data{broker: @test_broker,
                         data: :test,
                         channel: ^channel},
                   300  # From Proxy rerouted by Broker

    Broker.stop broker
    assert_receive {:unsubscribed, @test_broker, ^channel}  # From Broker
    Proxy.unsubscribe proxy, handle
  end
end
