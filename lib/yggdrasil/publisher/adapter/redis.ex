defmodule Yggdrasil.Publisher.Adapter.Redis do
  @moduledoc """
  Yggdrasil publisher adapter for Redis. The name of the channel must be a
  binary e.g:

  Subscription to channel:

  ```
  iex(1)> channel = %Yggdrasil.Channel{name: "redis_channel", adapter: :redis}
  iex(2)> Yggdrasil.subscribe(channel)
  :ok
  iex(3)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: "redis_channel", (...)}}
  ```

  Publishing message:

  ```
  iex(4)> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  Subscriber receiving message:

  ```
  iex(5)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: "redis_channel", (...)}, "foo"}
  ```

  The subscriber can also unsubscribe from the channel:

  ```
  iex(6)> Yggdrasil.unsubscribe(channel)
  :ok
  iex(7)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{name: "redis_channel", (...)}}
  ```
  """
  use GenServer

  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Adapter.Redis

  defstruct [:conn, :namespace]
  alias __MODULE__, as: State

  ############
  # Client API

  @doc """
  Starts a Redis publisher with a `namespace`. Additianally you can add
  `GenServer` `options`.
  """
  @spec start_link(term()) :: GenServer.on_start()
  @spec start_link(term(), GenServer.options()) :: GenServer.on_start()
  def start_link(namespace, options \\ [])

  def start_link(namespace, options) do
    GenServer.start_link(__MODULE__, namespace, options)
  end

  @doc """
  Stops a Redis `publisher`.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(publisher)

  def stop(publisher) do
    GenServer.stop(publisher)
  end

  @doc """
  Publishes a `message` in a `channel` using a `publisher` and optional unused
  `options`.
  """
  @spec publish(GenServer.server(), Channel.t(), term()) ::
    :ok | {:error, term()}
  @spec publish(GenServer.server(), Channel.t(), term(), Keyword.t()) ::
    :ok | {:error, term()}
  def publish(publisher, channel, message, options \\ [])

  def publish(publisher, %Channel{} = channel, message, _options) do
    GenServer.call(publisher, {:publish, channel, message})
  end

  ####################
  # GenServer callback

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
