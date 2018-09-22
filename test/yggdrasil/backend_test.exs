defmodule Yggdrasil.BackendTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry

  describe "Default subscription cycle:" do
    setup do
      {:ok, channel} =
        %Channel{name: "subscription cycle"}
        |> Registry.get_full_channel()
      {:ok, channel: channel}
    end

    test "channel transformation is binary", %{channel: channel}do
      assert is_binary(Backend.transform_name(channel))
    end

    test "subscriber receives published message", %{channel: channel} do
      assert :ok = Backend.subscribe(channel)
      assert :ok = Backend.publish(channel, "message")
      assert_receive {:Y_EVENT, _, "message"}, 500
    end

    test "connected message to subscribers", %{channel: channel} do
      assert :ok = Backend.subscribe(channel)
      assert :ok = Backend.connected(channel)
      assert_receive {:Y_CONNECTED, _}
    end

    test "connected message to PID", %{channel: channel} do
      assert :ok = Backend.connected(channel, self())
      assert_receive {:Y_CONNECTED, _}
    end

    test "disconnected message to subscribers", %{channel: channel} do
      assert :ok = Backend.subscribe(channel)
      assert :ok = Backend.disconnected(channel)
      assert_receive {:Y_DISCONNECTED, _}
    end

    test "disconnected message to PID", %{channel: channel} do
      assert :ok = Backend.disconnected(channel, self())
      assert_receive {:Y_DISCONNECTED, _}
    end
  end
end
