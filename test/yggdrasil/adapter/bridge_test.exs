defmodule Yggdrasil.Adapter.BridgeTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Adapter.Bridge
  alias Yggdrasil.Adapter.Bridge.Generator
  alias Yggdrasil.Channel

  describe "split_channels/1" do
    test "gets the channels" do
      channel = %Channel{name: [name: :foo], adapter: :bridge}
      assert {:ok, {local, remote}} = Bridge.split_channels(channel)
      assert %Channel{name: {:"$yggdrasil_bridge", _}} = local
      assert %Channel{name: :foo, adapter: :elixir} = remote
    end
  end

  describe "full cycle" do
    setup do
      remote = %Channel{
        name: make_ref(),
        backend: :default,
        transformer: :default,
        adapter: :elixir
      }

      local = %Channel{
        name: remote,
        backend: :default,
        transformer: :default,
        adapter: :bridge
      }

      {:ok, [local: local, remote: remote]}
    end

    test "starts remote subscriber on subscription", %{
      local: local,
      remote: remote
    } do
      assert :ok = Yggdrasil.subscribe(local)
      assert_receive {:Y_CONNECTED, ^local}

      pid = get_remote_subscriber(remote)

      assert Process.alive?(pid)
    end

    test "stops remote subscriber on unsubscription", %{
      local: local,
      remote: remote
    } do
      assert :ok = Yggdrasil.subscribe(local)
      assert_receive {:Y_CONNECTED, ^local}

      pid = get_remote_subscriber(remote)

      Process.monitor(pid)
      assert :ok = Yggdrasil.unsubscribe(local)
      assert_receive {:Y_DISCONNECTED, ^local}
      assert_receive {:DOWN, _, _, ^pid, _}
    end
  end

  defp get_remote_subscriber(remote) do
    Generator
    |> DynamicSupervisor.which_children()
    |> Stream.map(fn {_, pid, _, _} -> pid end)
    |> Stream.map(fn pid -> {pid, :sys.get_state(pid)} end)
    |> Enum.filter(fn {_, %{channel: channel}} -> channel == remote end)
    |> List.first()
    |> elem(0)
  end
end
