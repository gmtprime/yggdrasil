defmodule Yggdrasil.Adapter.PostgresTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel

  test "postgres subscriber" do
    channel_name = "yggdrasil_test"
    channel = %Channel{decoder: Yggdrasil.Decoder.Default.Postgres,
                       channel: channel_name}
    {:ok, client} = TestClient.start_link(self(), channel)
    assert_receive :ready, 5000

    options = Application.get_env(:yggdrasil, :postgres, [])
    {:ok, conn} = Postgrex.start_link(options)

    {:ok, _} = Postgrex.query(conn, "NOTIFY #{channel_name}, 'message'", [])

    assert_receive {:event, ^channel_name, "message"}, 5000

    TestClient.stop(client)
    GenServer.stop(conn)
  end
end
