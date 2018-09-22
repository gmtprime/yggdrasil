defmodule Yggdrasil.Publisher.AdapterTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Adapter
  alias Yggdrasil.Registry

  test "publish" do
    {:ok, channel} = Registry.get_full_channel(%Channel{name: UUID.uuid4()})
    :ok = Yggdrasil.subscribe(channel)

    assert_receive {:Y_CONNECTED, _}, 500

    assert {:ok, adapter} = Adapter.start_link(channel)
    assert :ok = Adapter.publish(adapter, channel, "message", [])
    assert_receive {:Y_EVENT, _, "message"}, 500
    assert :ok = Adapter.stop(adapter)
  end
end
