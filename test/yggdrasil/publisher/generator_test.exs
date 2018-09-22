defmodule Yggdrasil.Publisher.GeneratorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher
  alias Yggdrasil.Publisher.Generator
  alias Yggdrasil.Registry

  test "start publisher" do
    {:ok, channel} = Registry.get_full_channel(
      %Channel{name: UUID.uuid4(), namespace: StartPublisherTest}
    )
    Yggdrasil.subscribe(channel)

    assert_receive {:Y_CONNECTED, _}, 500

    assert {:ok, generator} = Generator.start_link()
    assert {:ok, _} = Generator.start_publisher(generator, channel)
    assert :ok = Publisher.publish(channel, "message")
    assert_receive {:Y_EVENT, _, "message"}, 500
    assert :ok = Generator.stop(generator)

    Yggdrasil.unsubscribe(channel)
  end

  test "start publisher twice" do
    {:ok, channel} = Registry.get_full_channel(
      %Channel{name: UUID.uuid4(), namespace: StartPublisherTwiceTest}
    )
    Yggdrasil.subscribe(channel)

    assert_receive {:Y_CONNECTED, _}, 500

    assert {:ok, generator} = Generator.start_link()
    assert {:ok, publisher} = Generator.start_publisher(generator, channel)
    assert {:ok, {:already_connected, ^publisher}} =
           Generator.start_publisher(generator, channel)

    assert :ok = Publisher.publish(channel, "message")
    assert_receive {:Y_EVENT, _, "message"}, 500
    assert :ok = Generator.stop(generator)

    Yggdrasil.unsubscribe(channel)
  end
end
