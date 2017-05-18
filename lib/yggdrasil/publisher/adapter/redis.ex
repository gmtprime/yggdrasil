defmodule Yggdrasil.Publisher.Adapter.Redis do
  @moduledoc """
  Yggdrasil publisher adapter for Redis. The name of the channel must be a
  binary e.g:

  Subscription to channel:

  ```elixir
  iex(1)> alias Yggdrasil.Channel
  iex(2)> sub_channel = %Channel{
  ...(2)>   name: "redis_channel",
  ...(2)>   adapter: Yggdrasil.Subscriber.Adapter.Redis
  ...(2)> }
  iex(3)> Yggdrasil.subscribe(sub_channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Channel{name: "redis_channel", (...)}}
  ```

  Publishing message:

  ```elixir
  iex(5)> pub_channel = %Channel{
  ...(5)>   name: "redis_channel",
  ...(5)>   adapter: Yggdrasil.Publisher.Adapter.Redis
  ...(5)> }
  iex(6)> Yggdrasil.publish(pub_channel, "message")
  :ok
  ```

  Subscriber receiving message:

  ```elixir
  iex(7)> flush()
  {:Y_EVENT, %Channel{name: "redis_channel", (...)}, "message"}
  ```

  Instead of having `sub_channel` and `pub_channel`, the hibrid channel can be
  used. For the previous example we can do the following:

  ```elixir
  iex(1)> alias Yggdrasil.Channel
  iex(2)> channel = %Channel{name: "redis_channel", adapter: :redis}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Channel{name: "redis_channel", (...)}}
  iex(5)> Yggdrasil.publish(channel, "message")
  :ok
  iex(6)> flush()
  {:Y_EVENT, %Channel{name: "redis_channel", (...)}, "message"} 
  """
  use GenServer

  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Adapter.Redis

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
