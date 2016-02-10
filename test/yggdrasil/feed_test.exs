defmodule Yggdrasil.FeedTest do
  use ExUnit.Case, async: true
  require Logger
  alias Yggdrasil.MessengerSupervisor, as: BrokerSup
  alias Yggdrasil.Proxy, as: Proxy
  alias Yggdrasil.Proxy.Data, as: Data
  alias Yggdrasil.Util.Forwarder, as: Forwarder
  alias Yggdrasil.Feed, as: Feed

  @test_broker Yggdrasil.Test.TestBroker
  @forwarder Yggdrasil.Util.Forwarder
  @messengers Yggdrasil.Messengers
  @subscribers Yggdrasil.Subscribers

  setup do
    Logger.remove_backend :console
    {:ok, broker_sup} = BrokerSup.start_link
    {:ok, proxy} = Proxy.start_link
    forwarder = Forwarder.set_parent @forwarder
    {:ok, %{broker_sup: broker_sup, proxy: proxy, forwarder: forwarder}}
  end

  test "start/stop",
       %{broker_sup: broker_sup, proxy: proxy, forwarder: forwarder} do
    messengers = :ets.new @messengers,
                          [:set, :public, read_concurrency: true]
    subscribers = :ets.new @subscribers,
                           [:set, :public, read_concurrency: true]
    {:ok, feed} = Feed.start_link broker_sup, proxy, subscribers, messengers,
                                  forwarder
    Feed.stop feed
    assert_receive {:terminated, :normal, ^feed}
  end
  
  test "subscribe/unsubscribe",
       %{broker_sup: broker_sup, proxy: proxy, forwarder: forwarder} do
    messengers = :ets.new @messengers,
                          [:set, :public, read_concurrency: true]
    subscribers = :ets.new @subscribers,
                           [:set, :public, read_concurrency: true]
    {:ok, feed} = Feed.start_link broker_sup, proxy, subscribers, messengers,
                                  forwarder
    {:ok, handler} = Feed.subscribe feed, @test_broker, :channel
    assert_receive {:subscribed, @test_broker, :channel} # From Broker 
    assert_receive {:subscribers, @test_broker, :channel, 1} # From Feed
    Feed.unsubscribe feed, handler
    assert_receive {:unsubscribed, @test_broker, :channel} # From Broker 
    assert_receive {:subscribers, @test_broker, :channel, 0} # From Feed
    Feed.stop feed
    assert_receive {:terminated, :normal, ^feed}
  end

  test "subscribe/unsusbcribe with Feed restart",
       %{broker_sup: broker_sup, proxy: proxy, forwarder: forwarder} do
    messengers = :ets.new @messengers,
                          [:set, :public, read_concurrency: true]
    subscribers = :ets.new @subscribers,
                           [:set, :public, read_concurrency: true]
    {:ok, feed} = Feed.start_link broker_sup, proxy, subscribers, messengers,
                                  forwarder
    {:ok, handler} = Feed.subscribe feed, @test_broker, :channel
    assert_receive {:broker_conn, conn}
    assert_receive {:subscribed, @test_broker, :channel} # From Broker 
    assert_receive {:subscribers, @test_broker, :channel, 1} # From Feed
    @test_broker.publish conn, :channel, :test
    assert_receive {:message, @test_broker, :channel, :test} # From Forwarder
    assert_receive %Data{broker: @test_broker,
                         data: :test,
                         channel: :channel}  # From Proxy
    Process.unlink feed
    Process.exit feed, :kill
    {:ok, feed} = Feed.start_link broker_sup, proxy, subscribers, messengers,
                                  forwarder
    @test_broker.publish conn, :channel, :test
    assert_receive {:message, @test_broker, :channel, :test} # From Forwarder
    assert_receive %Data{broker: @test_broker,
                         data: :test,
                         channel: :channel}  # From Proxy
    Feed.unsubscribe feed, handler
    assert_receive {:unsubscribed, @test_broker, :channel} # From Broker 
    assert_receive {:subscribers, @test_broker, :channel, 0} # From Feed
    Feed.stop feed
    assert_receive {:terminated, :normal, ^feed}
  end

  test "subscribe/unsusbcribe with Broker restart",
       %{broker_sup: broker_sup, proxy: proxy, forwarder: forwarder} do
    messengers = :ets.new @messengers,
                          [:set, :public, read_concurrency: true]
    subscribers = :ets.new @subscribers,
                           [:set, :public, read_concurrency: true]
    {:ok, feed} = Feed.start_link broker_sup, proxy, subscribers, messengers,
                                  forwarder
    {:ok, handler} = Feed.subscribe feed, @test_broker, :channel
    assert_receive {:broker_conn, conn}
    assert_receive {:subscribed, @test_broker, :channel} # From Broker 
    assert_receive {:subscribers, @test_broker, :channel, 1} # From Feed
    @test_broker.publish conn, :channel, :test
    assert_receive {:message, @test_broker, :channel, :test} # From Forwarder
    assert_receive %Data{broker: @test_broker,
                         data: :test,
                         channel: :channel}  # From Proxy
    Process.exit conn, :kill
    assert_receive {:broker_conn, conn}
    @test_broker.publish conn, :channel, :test
    assert_receive {:message, @test_broker, :channel, :test} # From Forwarder
    assert_receive %Data{broker: @test_broker,
                         data: :test,
                         channel: :channel}  # From Proxy
    Feed.unsubscribe feed, handler
    assert_receive {:unsubscribed, @test_broker, :channel} # From Broker 
    assert_receive {:subscribers, @test_broker, :channel, 0} # From Feed
    Feed.stop feed
    assert_receive {:terminated, :normal, ^feed}
  end
end
