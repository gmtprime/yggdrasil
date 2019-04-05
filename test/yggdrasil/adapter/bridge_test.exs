defmodule Yggdrasil.Adapter.BridgeTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Adapter.Bridge
  alias Yggdrasil.Channel

  describe "split_channels/1" do
    test "gets the channels" do
      channel = %Channel{name: [name: :foo], adapter: :bridge}
      assert {:ok, {local, remote}} = Bridge.split_channels(channel)
      assert %Channel{name: {:"$yggdrasil_bridge", _}} = local
      assert %Channel{name: :foo, adapter: :elixir} = remote
    end
  end
end
