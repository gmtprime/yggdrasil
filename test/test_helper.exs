defmodule TestClient do
  use YProcess, backend: Yggdrasil.Backend

  defstruct [:parent, :channel, :timeout]
  alias __MODULE__, as: State

  def start_link(parent, channels) do
    start_link(parent, channels, 500)
  end

  def start_link(parent, channels, timeout) when is_list(channels) do
    state = %State{parent: parent, channel: channels, timeout: timeout}
    YProcess.start_link(__MODULE__, state)
  end
  def start_link(parent, channel, timeout) do
    start_link(parent, [channel], timeout)
  end

  def stop(client) do
    YProcess.stop(client)
  end

  def init(%State{channel: channels, timeout: timeout} = state) do
    {:join, channels, state, timeout}
  end

  def handle_info(:timeout, %State{parent: parent} = state) do
    send parent, :ready
    {:noreply, state}
  end

  def handle_event(channel, message, %State{parent: parent} = state) do
    send parent, {:event, channel, message}
    {:noreply, state}
  end
end

ExUnit.start()
