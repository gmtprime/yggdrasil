defmodule Yggdrasil.Publisher.GeneratorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher
  alias Yggdrasil.Publisher.Generator

  test "start publisher" do
    name = UUID.uuid4()
    sub_channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: PublisherGenTest0
    }
    Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}
    pub_channel = %Channel{
      adapter: Yggdrasil.Publisher.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: PublisherGenTest0
    }

    assert {:ok, generator} = Generator.start_link()
    assert {:ok, _} = Generator.start_publisher(generator, pub_channel)
    assert :ok = Publisher.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}
    assert :ok = Generator.stop(generator)

    Yggdrasil.unsubscribe(sub_channel)
  end

  test "start publisher twice" do
    name = UUID.uuid4()
    sub_channel = %Channel{
      adapter: Yggdrasil.Distributor.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: PublisherGenTest1
    }
    Yggdrasil.subscribe(sub_channel)

    assert_receive {:Y_CONNECTED, ^sub_channel}
    pub_channel = %Channel{
      adapter: Yggdrasil.Publisher.Adapter.Elixir,
      transformer: Yggdrasil.Transformer.Default,
      name: name,
      namespace: PublisherGenTest1
    }

    assert {:ok, generator} = Generator.start_link()
    assert {:ok, publisher} = Generator.start_publisher(generator, pub_channel)
    assert {:ok, {:already_connected, ^publisher}} =
      Generator.start_publisher(generator, pub_channel)
    assert :ok = Publisher.publish(pub_channel, "message")
    assert_receive {:Y_EVENT, ^sub_channel, "message"}
    assert :ok = Generator.stop(generator)

    Yggdrasil.unsubscribe(sub_channel)
  end
end
