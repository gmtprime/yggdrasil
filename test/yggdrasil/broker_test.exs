defmodule Yggdrasil.BrokerTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Broker
  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Generator

  defp get_monitors_table do
    :ets.new(:monitors, [:set, :public, read_concurrency: true,
                         write_concurrency: false])
  end

  setup do
    Application.ensure_started(:yggdrasil)
  end

  test "start/stop broker" do
    {:ok, generator} = Generator.start_link()
    monitors = get_monitors_table()
    assert {:ok, broker} = Broker.start_link(generator, monitors)
    Broker.stop(broker)
    Generator.stop(generator)
  end

  test "subscribe/2 to channel" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    {:ok, generator} = Generator.start_link()
    monitors = get_monitors_table()
    assert {:ok, broker} = Broker.start_link(generator, monitors)
    Broker.subscribe(broker, channel)
    assert [^channel] = Broker.get_channels(broker)
    Broker.stop(broker)
    Generator.stop(generator)
  end

  test "subscribe/3 to channel" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    {:ok, generator} = Generator.start_link()
    monitors = get_monitors_table()
    assert {:ok, broker} = Broker.start_link(generator, monitors)
    Broker.subscribe(broker, channel, self())
    assert [^channel] = Broker.get_channels(broker, self())
    Broker.stop(broker)
    Generator.stop(generator)
  end

  test "unsubscribe/2 to channel" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    {:ok, generator} = Generator.start_link()
    monitors = get_monitors_table()
    assert {:ok, broker} = Broker.start_link(generator, monitors)
    Broker.subscribe(broker, channel)
    assert [^channel] = Broker.get_channels(broker)
    Broker.unsubscribe(broker, channel)
    assert [] = Broker.get_channels(broker)
    Broker.stop(broker)
    Generator.stop(generator)
  end

  test "unsubscribe/3 to channel" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    {:ok, generator} = Generator.start_link()
    monitors = get_monitors_table()
    assert {:ok, broker} = Broker.start_link(generator, monitors)
    Broker.subscribe(broker, channel, self())
    assert [^channel] = Broker.get_channels(broker, self())
    Broker.unsubscribe(broker, channel, self())
    assert [] = Broker.get_channels(broker, self())
    Broker.stop(broker)
    Generator.stop(generator)
  end

  test "subscribe once to channel" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    {:ok, generator} = Generator.start_link()
    monitors = get_monitors_table()
    assert {:ok, broker} = Broker.start_link(generator, monitors)
    Broker.subscribe(broker, channel)
    Broker.subscribe(broker, channel)
    assert [^channel] = Broker.get_channels(broker)
    Broker.stop(broker)
    Generator.stop(generator)
  end

  test "unsubscribe once to channel" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    {:ok, generator} = Generator.start_link()
    monitors = get_monitors_table()
    assert {:ok, broker} = Broker.start_link(generator, monitors)
    Broker.subscribe(broker, channel)
    assert [^channel] = Broker.get_channels(broker)
    Broker.unsubscribe(broker, channel)
    Broker.unsubscribe(broker, channel)
    assert [] = Broker.get_channels(broker)
    Broker.stop(broker)
    Generator.stop(generator)
  end

  test "subscribe several clients" do
    ch0 = %Channel{channel: make_ref(), decoder: Yggdrasil.Decoder.Default}
    ch1 = %Channel{channel: make_ref(), decoder: Yggdrasil.Decoder.Default}
    ch2 = %Channel{channel: make_ref(), decoder: Yggdrasil.Decoder.Default}
    {:ok, client0} = TestClient.start_link(self(), [ch0, ch1])
    {:ok, client1} = TestClient.start_link(self(), [ch1, ch2])
    TestClient.stop(client1)
    assert 1 = Broker.count_subscribers(Yggdrasil.Broker, ch0)
    assert 1 = Broker.count_subscribers(Yggdrasil.Broker, ch1)
    assert 0 = Broker.count_subscribers(Yggdrasil.Broker, ch2)
    TestClient.stop(client0)
  end
end
