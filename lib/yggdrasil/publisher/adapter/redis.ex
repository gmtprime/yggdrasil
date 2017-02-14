defmodule Yggdrasil.Publisher.Adapter.Redis do
  @moduledoc """
  A server for Redis publishing.

  The name of a channel is a string.
  """
  use GenServer

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Adapter.Redis

  defstruct [:conn, :namespace]
  alias __MODULE__, as: State

  #############################################################################
  # Client API.

  @doc """
  Starts a Redis publisher with a `namespace`. Additianally you can add
  `GenServer` `options`.
  """
  def start_link(namespace, options \\ []) do
    GenServer.start_link(__MODULE__, namespace, options)
  end

  @doc """
  Stops a Redis `publisher`.
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
  def init(namespace) do
    options = Redis.redis_options(%Channel{namespace: namespace})
    {:ok, conn} = Redix.start_link(options)
    state = %State{conn: conn, namespace: namespace}
    {:ok, state}
  end

  @doc false
  def handle_call(
    {:publish, %Channel{transformer: encoder, name: name} = channel, message},
    _from,
    %State{conn: conn} = state
  ) do
    result =
      with {:ok, encoded} <- encoder.encode(channel, message),
           {:ok, _} = Redix.command(conn, ~w(PUBLISH #{name} #{encoded})),
           do: :ok
    {:reply, result, state}
  end

  @doc false
  def terminate(_reason, %State{conn: conn}) do
    Redix.stop(conn)
    :ok
  end
end
