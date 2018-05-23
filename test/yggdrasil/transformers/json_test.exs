defmodule Yggdrasil.Transformer.JsonTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Transformer.Json

  test "decode/2" do
    channel = %Channel{}
    decoded = %{"hello" => "world"}
    assert {:ok, ^decoded} = Json.decode(channel, "{\"hello\":\"world\"}")
  end

  test "encode/2" do
    channel = %Channel{}
    encoded = "{\"hello\":\"world\"}"
    assert {:ok, ^encoded} = Json.encode(channel, %{"hello" => "world"})
  end
end
