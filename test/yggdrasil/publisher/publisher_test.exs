defmodule Yggdrasil.PublisherTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher

  test "publish message" do
    name = UUID.uuid4()
    sub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Subscriber.Adapter.Elixir,
      namespace: PublisherTest
    }
    Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}, 500
    pub_channel = %Channel{
      name: name,
      adapter: Yggdrasil.Publisher.Adapter.Elixir,
      namespace: PublisherTest
    }
    assert {:ok, publisher} = Publisher.start_link(pub_channel)
    assert :ok = Publisher.publish(pub_channel, "message")
    assert :ok = Publisher.stop(publisher)
    assert_receive {:Y_EVENT, ^sub_channel, "message"}, 500

    Yggdrasil.unsubscribe(sub_channel)
  end
end
