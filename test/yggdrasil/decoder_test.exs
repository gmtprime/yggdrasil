defmodule Yggdrasil.DecoderTest do
  use ExUnit.Case, async: true

  defmodule Message do
    defstruct [:message, :channel]
  end

  defmodule TestDecoder do
    use Yggdrasil.Decoder, adapter: Custom

    def decode(channel, message) do
      %Message{channel: channel, message: message}
    end
  end

  test "decode/2" do
    ref = make_ref()
    expected = %Message{channel: ref, message: :message}
    decoded = TestDecoder.decode(ref, :message)
    assert expected === decoded
  end
end
