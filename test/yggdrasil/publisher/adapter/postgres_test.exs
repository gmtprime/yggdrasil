defmodule Yggdrasil.Publisher.Adapter.PostgresTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Adapter.Postgres

  test "publisher" do
    name = "postgres_2"
    sub_channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Postgres,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    :ok = Yggdrasil.subscribe(sub_channel)
    
    assert_receive {:Y_CONNECTED, ^sub_channel}, 500
    pub_channel = %Channel{
      adapter: Yggdrasil.Publisher.Adapter.Postgres,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: Test
    }
    assert {:ok, adapter} = Postgres.start_link(Test)
    assert :ok = Postgres.publish(adapter, pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 500
    assert :ok = Postgres.stop(adapter)

    :ok = Yggdrasil.unsubscribe(sub_channel)
  end
end
