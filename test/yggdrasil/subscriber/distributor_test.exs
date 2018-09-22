defmodule Yggdrasil.Subscriber.DistributorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Subscriber.Distributor

  test "start - stop" do
    {:ok, channel} = Registry.get_full_channel(%Channel{name: UUID.uuid4()})
    Backend.subscribe(channel)
    assert {:ok, distributor} = Distributor.start_link(channel, self())
    ref = Process.monitor(distributor)
    assert :ok = Distributor.stop(distributor)
    assert_receive {:DOWN, ^ref, :process, ^distributor, :normal}
    Backend.unsubscribe(channel)
  end

  test "distribution" do
    name = UUID.uuid4()
    {:ok, channel} = Registry.get_full_channel(%Channel{name: name})
    Backend.subscribe(channel)
    {:ok, distributor} = Distributor.start_link(channel, self())

    assert_receive {:Y_CONNECTED, _}, 500
    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, _, "message"}, 500

    :ok = Distributor.stop(distributor)
    assert_receive {:Y_DISCONNECTED, _}, 500

    Backend.unsubscribe(channel)
  end
end
