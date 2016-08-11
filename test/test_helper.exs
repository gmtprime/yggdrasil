defmodule TestClient do
  use YProcess, backend: Yggdrasil.Backend

  defstruct [:parent, :channel]
  alias __MODULE__, as: State

  def start_link(parent, channels) when is_list(channels) do
    state = %State{parent: parent, channel: channels}
    YProcess.start_link(__MODULE__, state)
  end
  def start_link(parent, channel) do
    start_link(parent, [channel])
  end

  def stop(client) do
    YProcess.stop(client)
  end

  def init(%State{channel: channels} = state) do
    {:join, channels, state}
  end

  def ready(:joined, _channels, %State{parent: parent} = state) do
    send parent, :ready
    {:noreply, state}
  end

  def handle_event(channel, message, %State{parent: parent} = state) do
    send parent, {:event, channel, message}
    {:noreply, state}
  end
end

ExUnit.start()
