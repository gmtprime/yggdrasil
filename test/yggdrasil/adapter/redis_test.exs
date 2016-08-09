defmodule Yggdrasil.Adapter.RedisTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel

  test "redis subscriber" do
    channel = %Channel{decoder: Yggdrasil.Decoder.Default.Redis,
                       channel: "redis_channel"}
    {:ok, client} = TestClient.start_link(self(), channel)
    assert_receive :ready, 600

    options = Application.get_env(:yggdrasil, :redis, [host: "localhost"])
    {:ok, conn} = Redix.start_link(options)
    {:ok, 1} = Redix.command(conn, ~w(PUBLISH #{"redis_channel"} #{"message"}))
    Redix.stop(conn)

    assert_receive {:event, "redis_channel", "message"}
    TestClient.stop(client)
  end
end
