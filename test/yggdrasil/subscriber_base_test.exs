defmodule Yggdrasil.SubscriberBaseTest do
  use ExUnit.Case, async: true
  alias Yggdrasil.Proxy.Data, as: Data
  alias Yggdrasil.Test.TestSubscriber, as: Subscriber
  alias Yggdrasil.Util.Forwarder, as: Forwarder

  @forwarder Yggdrasil.Util.Forwarder

  setup do
    forwarder = Forwarder.set_parent @forwarder
    {:ok, %{forwarder: forwarder}}
  end

  test "init/1 - terminate/2", %{forwarder: forwarder} do
    {:ok, pid} = Subscriber.start_link Yggdrasil.Feed, forwarder
    assert_receive {:started, ^pid}
    Subscriber.stop pid
    assert_receive {:stopped, :normal, ^pid}
  end

  test "subscribe/2 - unsubscribe/2", %{forwarder: forwarder} do
    {:ok, pid} = Subscriber.start_link Yggdrasil.Feed, forwarder
    assert_receive {:started, ^pid}
    channel = "tress"

    assert :ok == Subscriber.subscribe pid, channel
    assert {:error, :already_subscribed} = Subscriber.subscribe(pid, channel)
    
    assert :ok == Subscriber.unsubscribe pid, channel
    assert {:error, :already_unsubscribed} = Subscriber.unsubscribe(pid, channel)
    
    Subscriber.stop pid
    assert_receive {:stopped, :normal, ^pid}
  end

  test "handle_message/2", %{forwarder: forwarder} do
    {:ok, pid} = Subscriber.start_link Yggdrasil.Feed, forwarder
    assert_receive {:started, ^pid}
    channel = "tress"

    assert :ok == Subscriber.subscribe pid, channel

    {:ok, publisher} = Exredis.start_link
    message = "Yggdrasil!"
    publisher |> Exredis.Api.publish(channel, message)
    assert_receive {:received,
                    %Data{broker: Yggdrasil.Broker.Redis,
                          channel: ^channel,
                          data: ^message}}
    Exredis.stop publisher
    
    assert :ok == Subscriber.unsubscribe pid, channel
    
    Subscriber.stop pid
    assert_receive {:stopped, :normal, ^pid}
  end

  test "register/2", %{forwarder: forwarder} do
    {:ok, pid} = Subscriber.start_link Yggdrasil.Feed

    assert :ok == Subscriber.register pid, forwarder

    channel = "tress"

    assert :ok == Subscriber.subscribe pid, channel

    {:ok, publisher} = Exredis.start_link
    message = "Yggdrasil!"
    publisher |> Exredis.Api.publish(channel, message)
    assert_receive {:received,
                    %Data{broker: Yggdrasil.Broker.Redis,
                          channel: ^channel,
                          data: ^message}}
    Exredis.stop publisher
    
    assert :ok == Subscriber.unsubscribe pid, channel
    
    Subscriber.stop pid
    assert_receive {:stopped, :normal, ^pid}
  
  end
end
