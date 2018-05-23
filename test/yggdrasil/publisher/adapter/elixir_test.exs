defmodule Yggdrasil.Publisher.Adapter.ElixirTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Adapter.Elixir, as: Basic

  test "publish" do
    name = UUID.uuid4()
    sub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
    :ok = Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}, 500
    pub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Publisher.Adapter.Elixir
    }
    assert {:ok, adapter} = Basic.start_link(nil)
    assert :ok = Basic.publish(adapter, pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 500
    assert :ok = Basic.stop(adapter)

    :ok = Yggdrasil.unsubscribe(sub_channel)
    assert_receive {:Y_DISCONNECTED, ^sub_channel}, 500
  end
end
