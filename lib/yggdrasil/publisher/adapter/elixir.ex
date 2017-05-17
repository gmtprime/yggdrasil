defmodule Yggdrasil.Publisher.Adapter.Elixir do
  @moduledoc """
  A server for elixir publishing.

  The name of a channel is an arbitrary Elixir term.
  """
  use GenServer

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend

  #############################################################################
  # Client API.

  @doc """
  Starts an elixir publisher with a `namespace`. Additianally you can add
  `GenServer` `options`.
  """
  def start_link(_, options \\ []) do
    GenServer.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops an elixir `publisher`.
  """
  def stop(publisher) do
    GenServer.stop(publisher)
  end

  @doc """
  Publishes a `message` in a `channel` using a `publisher`.
  """
  def publish(publisher, %Channel{} = channel, message) do
    GenServer.call(publisher, {:publish, channel, message})
  end

  #############################################################################
  # GenServer callback.

  @doc false
  def init(_) do
    {:ok, nil}
  end

  @doc false
  def handle_call(
    {:publish, %Channel{transformer: encoder, name: name} = channel, message},
    _from,
    _state
  ) do
    stream = %Channel{
      channel | name: {:elixir, name},
                adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
    result =
      with {:ok, encoded} <- encoder.encode(stream, message),
           do: Backend.publish(stream, encoded)
    {:reply, result, nil}
  end
  def handle_call(_msg, _from, _state) do
    {:noreply, nil}
  end
end
