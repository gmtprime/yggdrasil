defmodule Yggdrasil.PublisherTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher
  alias Yggdrasil.Registry

  test "publish message" do
    {:ok, channel} =
      Registry.get_full_channel(%Channel{
        name: make_ref(),
        namespace: PublisherTest
      })

    Yggdrasil.subscribe(channel)

    assert_receive {:Y_CONNECTED, _}, 500
    assert {:ok, publisher} = Publisher.start_link(channel)
    assert :ok = Publisher.publish(channel, "message")
    assert_receive {:Y_EVENT, _, "message"}, 500
    assert :ok = Publisher.stop(publisher)

    Yggdrasil.unsubscribe(channel)
  end
end
