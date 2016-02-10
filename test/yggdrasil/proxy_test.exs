defmodule Yggdrasil.ProxyTest do
  use ExUnit.Case, async: true
  alias Yggdrasil.Proxy, as: Proxy
  alias Yggdrasil.Proxy.Data, as: Data

  test "subscribe default callback" do
    {:ok, proxy} = Proxy.start_link
    {:ok, handle} = Proxy.subscribe proxy, :broker, :channel
    Proxy.publish proxy, :broker, :channel, :test
    assert_receive %Data{broker: :broker, channel: :channel, data: :test}
    Proxy.unsubscribe proxy, handle
    assert GenEvent.which_handlers(proxy) == []
    Proxy.stop proxy
  end

  test "subscribe custom callback" do
    {:ok, proxy} = Proxy.start_link
    pid = self()
    {:ok, handle} = Proxy.subscribe proxy,
                                    :broker,
                                    :channel,
                                    &(send pid, {:custom, &1})
    Proxy.publish proxy, :broker, :channel, :test
    assert_receive {:custom, 
                    %Data{broker: :broker, channel: :channel, data: :test}}
    Proxy.unsubscribe proxy, handle
    assert GenEvent.which_handlers(proxy) == []
    Proxy.stop proxy
  end
end
