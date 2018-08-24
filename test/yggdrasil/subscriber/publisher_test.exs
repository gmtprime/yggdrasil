defmodule Yggdrasil.Subscriber.PublisherTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Backend
  alias Yggdrasil.Subscriber.Publisher

  test "starts and stops the process correctly" do
    channel = %Channel{name: UUID.uuid4()}

    assert {:ok, publisher} = Publisher.start_link(channel)
    ref = Process.monitor(publisher)

    assert :ok = Publisher.stop(publisher)
    assert_receive {:DOWN, ^ref, :process, ^publisher, :normal}
  end

  test "Forwards a messages to the subscribers" do
    name = UUID.uuid4()
    channel = %Channel{name: name}
    Backend.subscribe(channel)
    {:ok, publisher} = Publisher.start_link(channel)

    assert :ok = Publisher.notify(publisher, name, "message")
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    Backend.unsubscribe(channel)
    Publisher.stop(publisher)
  end
end
