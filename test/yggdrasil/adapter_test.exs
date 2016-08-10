defmodule Yggdrasil.AdapterTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher
  alias Yggdrasil.Adapter.Elixir, as: Adapter

  defmodule TestProducer do
    use YProcess, backend: Yggdrasil.Backend

    def start_link(channel) do
      YProcess.start_link(__MODULE__, channel)
    end

    def stop(producer) do
      YProcess.stop(producer)
    end

    def send_event(producer, message) do
      YProcess.call(producer, {:event, message})
    end

    def init(channel) do
      {:create, [channel], channel}
    end

    def handle_call({:event, message}, _from, channel) do
      {:remit, [channel], message, :ok, channel}
    end
  end

  test "adapter resends message to publisher" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    channel_name = Adapter.get_channel_name(ref)
    
    {:ok, client} = TestClient.start_link(self(), ref)
    {:ok, publisher} = Publisher.start_link(channel)
    {:ok, adapter} = Adapter.start_link(channel, publisher)
    {:ok, producer} = TestProducer.start_link(channel_name)
    assert_receive :ready, 600

    assert :ok = TestProducer.send_event(producer, :message)
    assert_receive {:event, ^ref, :message}

    TestProducer.stop(producer)
    Adapter.stop(adapter)
    Publisher.stop(publisher)
    TestClient.stop(client)
  end
end
