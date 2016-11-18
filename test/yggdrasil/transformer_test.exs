defmodule Yggdrasil.TransformerTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel

  defmodule TransformerTest do
    use Yggdrasil.Transformer

    def decode(channel, message) do
      {:ok, {channel, message}}
    end

    def encode(channel, message) do
      {:ok, "#{inspect channel} - #{message}"}
    end
  end

  test "decode behaviour" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    decoded = {channel, "message"}
    assert {:ok, ^decoded} = TransformerTest.decode(channel, "message")
  end

  test "encode behaviour" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    encoded = "#{inspect channel} - message"
    assert {:ok, ^encoded} = TransformerTest.encode(channel, "message")
  end
end
