defmodule Yggdrasil.Publisher.SupervisorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Supervisor, as: PublisherSup

  test "start/stop publisher supervisor" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}
    
    {:ok, supervisor} = PublisherSup.start_link(channel) 
    [{Yggdrasil.Adapter.Elixir, adapter, _, _},
     {Yggdrasil.Publisher, publisher, _, _}] = Supervisor.which_children(supervisor)
    
    PublisherSup.stop(supervisor)
    
    assert not Process.alive?(adapter)
    assert not Process.alive?(publisher)
    assert not Process.alive?(supervisor)
  end
end
