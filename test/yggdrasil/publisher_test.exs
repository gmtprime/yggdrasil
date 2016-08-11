defmodule Yggdrasil.PublisherTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher

  test "start/stop publisher" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    
    {:ok, client} = TestClient.start_link(self(), ref)
    {:ok, publisher} = Publisher.start_link(channel)
    
    Publisher.stop(publisher)
    TestClient.stop(client)
  end

  test "sync_notify/3 publisher" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    
    {:ok, client} = TestClient.start_link(self(), ref)
    assert_receive :ready, 500
    {:ok, publisher} = Publisher.start_link(channel)
    
    assert :ok = Publisher.sync_notify(publisher, ref, :message)
    assert_receive {:event, ^ref, :message}, 500
    
    Publisher.stop(publisher)
    TestClient.stop(client)
  end

  test "async_notify/3 publisher" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    
    {:ok, client} = TestClient.start_link(self(), ref)
    assert_receive :ready, 500
    {:ok, publisher} = Publisher.start_link(channel)
    
    assert :ok = Publisher.async_notify(publisher, ref, :message)
    assert_receive {:event, ^ref, :message}, 500
    
    Publisher.stop(publisher)
    TestClient.stop(client)
  end
end
