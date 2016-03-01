defmodule Yggdrasil.Broker.GenericBrokerTest do
  use ExUnit.Case, async: true
  alias Yggdrasil.Proxy, as: Proxy
  alias Yggdrasil.Proxy.Data, as: Data
  alias Yggdrasil.Util.Forwarder, as: Forwarder
  alias Yggdrasil.Messenger, as: Broker
  require Logger

  @forwarder Yggdrasil.Util.Forwarder
  @generic_broker Yggdrasil.Test.TestGenericBroker

  setup do
    Logger.remove_backend :console
    {:ok, proxy} = Proxy.start_link
    forwarder = Forwarder.set_parent @forwarder
    {:ok, %{proxy: proxy, forwarder: forwarder, channel: :channel}}
  end

  test "subscribe/unsubscribe",
       %{proxy: proxy, forwarder: forwarder, channel: channel} do
    {:ok, handle} = Proxy.subscribe proxy, @generic_broker, channel
    {:ok, broker} = Broker.start_link @generic_broker, channel, proxy, forwarder
    assert_receive {:subscribed, @generic_broker, ^channel} # From Generic Br.
    assert_receive {:broker_conn, conn}  # From Generic Broker
    message = :yggdrasil
    
    Yggdrasil.Test.TestBroker.publish conn, channel, message
    assert_receive %Data{broker: @generic_broker,
                         data: "yggdrasil",
                         channel: ^channel}  # From Proxy rerouted by Broker
    assert [channel: "yggdrasil"] == :ets.lookup :test_cache, channel
    Broker.stop broker
    assert_receive {:unsubscribed, @generic_broker, ^channel}  # From Broker
    Proxy.unsubscribe proxy, handle
  end

  test "subscribe/unsubscribe timeout",
       %{proxy: proxy, forwarder: forwarder, channel: channel} do
    {:ok, handle} = Proxy.subscribe proxy, @generic_broker, channel
    {:ok, broker} = Broker.start_link @generic_broker, channel, proxy, forwarder
    assert_receive {:subscribed, @generic_broker, ^channel} # From Generic Br.
    assert_receive {:broker_conn, conn}  # From Generic Broker
    message = :yggdrasil
    
    Yggdrasil.Test.TestBroker.publish conn, channel, message
    assert_receive %Data{broker: @generic_broker,
                         data: "yggdrasil",
                         channel: ^channel}  # From Proxy rerouted by Broker
    assert [channel: "yggdrasil"] == :ets.lookup :test_cache, channel
    
    Yggdrasil.Test.TestBroker.publish conn, channel, message
    assert_receive %Data{broker: @generic_broker,
                         data: "yggdrasil",
                         channel: ^channel},
                   300# From Proxy rerouted by Broker
    assert [channel: "yggdrasil"] == :ets.lookup :test_cache, channel
    
    Broker.stop broker
    assert_receive {:unsubscribed, @generic_broker, ^channel}  # From Broker
    Proxy.unsubscribe proxy, handle
  end 
end
