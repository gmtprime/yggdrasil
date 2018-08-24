defmodule Yggdrasil.TransformerTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Transformer

  describe "Default transformer" do
    setup do
      {:ok, channel} =
        %Channel{name: "subscription cycle"}
        |> Registry.get_full_channel()
      {:ok, channel: channel}
    end

    test "decode does nothing to the message", %{channel: channel} do
      assert {:ok, "message"} = Transformer.decode(channel, "message")
    end

    test "encode does nothing to the message", %{channel: channel} do
      assert {:ok, "message"} = Transformer.encode(channel, "message")
    end
  end

  describe "Json transformer" do
    setup do
      {:ok, channel} =
        %Channel{name: "subscription cycle", transformer: :json}
        |> Registry.get_full_channel()
      json = "{\"hello\":\"world\"}"
      message = %{"hello" => "world"}
      {:ok, channel: channel, json: json, message: message}
    end

    test "decodes a JSON", %{channel: channel, json: json, message: message} do
      assert {:ok, ^message} = Transformer.decode(channel, json)
    end

    test "encodes a JSON", %{channel: channel, json: json, message: message} do
      assert {:ok, ^json} = Transformer.encode(channel, message)
    end
  end
end
