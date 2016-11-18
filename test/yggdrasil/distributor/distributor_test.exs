defmodule Yggdrasil.DistributorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor
  alias Yggdrasil.Distributor.Backend

  test "start - stop" do
    name = UUID.uuid4()
    channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name
    }
    Backend.subscribe(channel)
    assert {:ok, distributor} = Distributor.start_link(channel)
    assert :ok = Distributor.stop(distributor)
    Backend.unsubscribe(channel)
  end

  test "distribution" do
    name = UUID.uuid4()
    channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name
    }
    Backend.subscribe(channel)
    {:ok, distributor} = Distributor.start_link(channel)

    assert_receive {:Y_CONNECTED, ^channel}, 500
    stream = %Channel{channel | name: {:elixir, name}}
    Backend.publish(stream, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    :ok = Distributor.stop(distributor)
    Backend.unsubscribe(channel)
  end
end
