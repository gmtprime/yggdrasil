defmodule Yggdrasil.Subscriber.PublisherTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Publisher

  test "starts and stops the process correctly" do
    {:ok, channel} = Yggdrasil.gen_channel(name: make_ref())

    assert {:ok, publisher} = Publisher.start_link(channel)
    ref = Process.monitor(publisher)

    assert :ok = Publisher.stop(publisher)
    assert_receive {:DOWN, ^ref, :process, ^publisher, :normal}
  end

  test "Forwards a messages to the subscribers no metadata" do
    name = make_ref()
    {:ok, channel} = Yggdrasil.gen_channel(name: name)
    Backend.subscribe(channel)
    {:ok, publisher} = Publisher.start_link(channel)

    assert :ok = Publisher.notify(publisher, name, "message", nil)
    assert_receive {:Y_EVENT, ^channel, "message"}, 500

    Backend.unsubscribe(channel)
    Publisher.stop(publisher)
  end

  test "Forwards a messages to the subscribers with metadata" do
    name = make_ref()
    {:ok, channel} = Yggdrasil.gen_channel(name: name)
    Backend.subscribe(channel)
    {:ok, publisher} = Publisher.start_link(channel)

    assert :ok = Publisher.notify(publisher, name, "message", :metadata)
    assert_receive {:Y_EVENT, new_channel, "message"}, 500

    assert ^new_channel = %Channel{channel | metadata: :metadata}

    Backend.unsubscribe(channel)
    Publisher.stop(publisher)
  end
end
