defmodule Yggdrasil.Subscriber.Adapter.Elixir do
  @moduledoc """
  Yggdrasil subscriber adapter for Elixir. The name of the channel can be any
  arbitrary term e.g:

  First we subscribe to a channel:

  ```
  iex> channel = [name: "elixir_channel"]
  iex> Yggdrasil.subscribe(channel)
  :ok
  iex> flush()
  {:Y_CONNECTED, ...}
  ```

  Once connected, you can publish a message in that channel:

  ```
  iex> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  And the subscriber should receive the message:

  ```
  iex> flush()
  {:Y_EVENT, ..., "foo"}
  ```

  Additionally, the subscriber can also unsubscribe from the channel:

  ```
  iex> Yggdrasil.unsubscribe(channel)
  :ok
  iex> flush()
  {:Y_DISCONNECTED, ...}
  ```
  """
  use Yggdrasil.Subscriber.Adapter
  use GenServer

  require Logger

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Subscriber.Publisher

  defstruct [:external, :internal]
  alias __MODULE__, as: State

  ####################
  # GenServer callback

  @impl GenServer
  def init(%{channel: %Channel{name: name} = external}) do
    internal = %Channel{external | name: {:"$yggdrasil_elixir", name}}
    state = %State{external: external, internal: internal}

    Backend.subscribe(internal)
    Manager.connected(external)

    Logger.debug("Started #{__MODULE__} for #{inspect(external)}")

    {:ok, state}
  end

  @impl GenServer
  def handle_info({:Y_EVENT, _, message}, %State{external: external} = state) do
    Publisher.notify(external, message)
    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(:normal, %State{external: external, internal: internal}) do
    Backend.unsubscribe(internal)
    Manager.disconnected(external)
    Logger.debug("Stopped #{__MODULE__} for #{inspect(external)}")
  end

  def terminate(reason, %State{external: external, internal: internal}) do
    Backend.unsubscribe(internal)
    Manager.disconnected(external)

    Logger.warn(
      "Stopped #{__MODULE__} for #{inspect(external)} due to #{inspect(reason)}"
    )
  end
end
