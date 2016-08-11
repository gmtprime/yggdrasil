defmodule Yggdrasil.Publisher.GeneratorTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Generator

  test "start/stop generator" do
    {:ok, generator} = Generator.start_link()
    Generator.stop(generator)
  end

  test "start publisher/stop publisher" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}

    {:ok, generator} = Generator.start_link()
    {:ok, _} = Generator.start_publisher(generator, channel)
    assert %{active: 1} = Supervisor.count_children(generator)

    assert :ok = Generator.stop_publisher(channel)
    assert %{active: 0} = Supervisor.count_children(generator)
    Generator.stop(generator)
  end

  test "start publisher just once" do
    ref = make_ref()
    channel = %Channel{channel: ref, decoder: Yggdrasil.Decoder.Default}

    {:ok, generator} = Generator.start_link()
    {:ok, pid} = Generator.start_publisher(generator, channel)
    assert %{active: 1} = Supervisor.count_children(generator)
    {:ok, ^pid} = Generator.start_publisher(generator, channel)
    assert %{active: 1} = Supervisor.count_children(generator)

    assert :ok = Generator.stop_publisher(channel)
    assert %{active: 0} = Supervisor.count_children(generator)
    Generator.stop(generator)
  end
end
