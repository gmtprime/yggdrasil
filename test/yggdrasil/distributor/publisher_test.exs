defmodule Yggdrasil.Distributor.PublisherTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Distributor.Publisher

  test "start, stop" do
    name = UUID.uuid4()
    channel = %Channel{
      name: name
    }

    {:ok, publisher} = Publisher.start_link(channel)
    Publisher.stop(publisher)
  end

  test "notify" do
    name = UUID.uuid4()
    channel = %Channel{
      name: name
    }
    Backend.subscribe(channel)
    {:ok, publisher} = Publisher.start_link(channel)

    assert :ok = Publisher.notify(publisher, name, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    Backend.unsubscribe(channel)
    Publisher.stop(publisher)
  end
end
