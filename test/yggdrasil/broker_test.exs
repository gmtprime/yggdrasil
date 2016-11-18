defmodule Yggdrasil.BrokerTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Broker
  alias Yggdrasil.Distributor.Generator
  alias Yggdrasil.Distributor.Backend

  test "start - stop" do
    monitors = :ets.new(:monitors, [:set, :public, write_concurrency: false,
                                    read_concurrency: true])
    {:ok, generator} = Generator.start_link()

    assert {:ok, broker} = Broker.start_link(generator, monitors)
    assert :ok = Broker.stop(broker)
  end

  test "subscribe - unsubscribe" do
    monitors = :ets.new(:monitors, [:set, :public, write_concurrency: false,
                                    read_concurrency: true])
    {:ok, generator} = Generator.start_link()
    {:ok, broker} = Broker.start_link(generator, monitors)
    name = UUID.uuid4()
    channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name
    }

    assert :ok = Backend.subscribe(channel)
    assert :ok = Broker.subscribe(broker, channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500
    stream = %Channel{channel | name: {:elixir, name}}
    assert :ok = Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500
    assert :ok = Broker.unsubscribe(broker, channel)
    assert Backend.unsubscribe(channel)

    :ok = Broker.stop(broker)
  end

  test "subscribe twice" do
    monitors = :ets.new(:monitors, [:set, :public, write_concurrency: false,
                                    read_concurrency: true])
    {:ok, generator} = Generator.start_link()
    {:ok, broker} = Broker.start_link(generator, monitors)
    name = UUID.uuid4()
    channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name
    }

    assert :ok = Backend.subscribe(channel)
    assert :ok = Broker.subscribe(broker, channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500
    stream = %Channel{channel | name: {:elixir, name}}
    assert :ok = Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500
    assert :ok = Broker.subscribe(broker, channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500
    assert :ok = Broker.unsubscribe(broker, channel)
    assert Backend.unsubscribe(channel)

    :ok = Broker.stop(broker)
  end
end
