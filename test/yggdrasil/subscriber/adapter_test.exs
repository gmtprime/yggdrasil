defmodule Yggdrasil.Subscriber.AdapterTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Subscriber.Adapter
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Subscriber.Publisher

  test "start and stop" do
    {:ok, channel} = Registry.get_full_channel(%Channel{name: make_ref()})
    Backend.subscribe(channel)
    publisher = ExReg.local({Publisher, channel})
    manager = ExReg.local({Manager, channel})
    assert {:ok, _} = Publisher.start_link(channel, name: publisher)
    assert {:ok, _} = Manager.start_link(channel, self(), name: manager)

    assert {:ok, adapter} = Adapter.start_link(channel)
    assert_receive {:Y_CONNECTED, _}, 500

    assert :ok = Adapter.stop(adapter)
    assert_receive {:Y_DISCONNECTED, _}, 500
  end

  test "distribute message" do
    name = make_ref()
    {:ok, channel} = Registry.get_full_channel(%Channel{name: name})
    Backend.subscribe(channel)
    publisher = ExReg.local({Publisher, channel})
    manager = ExReg.local({Manager, channel})
    assert {:ok, _} = Publisher.start_link(channel, name: publisher)
    assert {:ok, _} = Manager.start_link(channel, self(), name: manager)

    assert {:ok, adapter} = Adapter.start_link(channel)
    assert_receive {:Y_CONNECTED, ^channel}, 500

    stream = %Channel{channel | name: {:"$yggdrasil_elixir", name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    assert :ok = Adapter.stop(adapter)
    assert_receive {:Y_DISCONNECTED, ^channel}, 500
  end
end
