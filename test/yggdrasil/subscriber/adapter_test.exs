defmodule Yggdrasil.Subscriber.AdapterTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Settings
  alias Yggdrasil.Subscriber.Adapter
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Subscriber.Publisher

  @registry Settings.yggdrasil_process_registry()

  test "start and stop" do
    {:ok, channel} = Registry.get_full_channel(%Channel{name: UUID.uuid4()})
    Backend.subscribe(channel)
    publisher = {:via, @registry, {Publisher, channel}}
    manager = {:via, @registry, {Manager, channel}}
    assert {:ok, _} = Publisher.start_link(channel, name: publisher)
    assert {:ok, _} = Manager.start_link(channel, name: manager)
    :ok = Manager.add(channel, self())

    assert {:ok, adapter} = Adapter.start_link(channel)
    assert_receive {:Y_CONNECTED, _}, 500

    assert :ok = Adapter.stop(adapter)
    assert_receive {:Y_DISCONNECTED, _}, 500
  end

  test "distribute message" do
    name = UUID.uuid4()
    {:ok, channel} = Registry.get_full_channel(%Channel{name: name})
    Backend.subscribe(channel)
    publisher = {:via, @registry, {Publisher, channel}}
    manager = {:via, @registry, {Manager, channel}}
    assert {:ok, _} = Publisher.start_link(channel, name: publisher)
    assert {:ok, _} = Manager.start_link(channel, name: manager)
    :ok = Manager.add(channel, self())

    assert {:ok, adapter} = Adapter.start_link(channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500

    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    assert :ok = Adapter.stop(adapter)
    assert_receive {:Y_DISCONNECTED, ^channel}, 500
  end
end
