defmodule YggdrasilTest do
  use ExUnit.Case
  doctest Yggdrasil

  @proxy Yggdrasil.Proxy
  @broker_sup Yggdrasil.MessengerSupervisor
  @feed Yggdrasil.Feed
  @forwarder Yggdrasil.Util.Forwarder

  test "All servers are up" do
    assert Process.whereis(@proxy) != nil
    assert Process.whereis(@broker_sup) != nil
    assert Process.whereis(@feed) != nil
    if Mix.env != :prod do
      assert Process.whereis(@forwarder) != nil
    end
  end
end
