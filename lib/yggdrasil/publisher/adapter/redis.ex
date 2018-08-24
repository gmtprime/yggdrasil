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
  use Yggdrasil.Publisher.Adapter
  use GenServer

  alias Yggdrasil.Channel
  alias Yggdrasil.Transformer
  alias Yggdrasil.Subscriber.Adapter.Redis

  defstruct [:conn, :namespace]
  alias __MODULE__, as: State

  ####################
  # GenServer callback

  @impl true
  def init(namespace) do
    options = Redis.redis_options(%Channel{namespace: namespace})
    {:ok, conn} = Redix.start_link(options)
    state = %State{conn: conn, namespace: namespace}
    {:ok, state}
  end

  @impl true
  def handle_call(
    {:publish, %Channel{name: name} = channel, message},
    _from,
    %State{conn: conn} = state
  ) do
    result =
      with {:ok, encoded} <- Transformer.encode(channel, message),
           {:ok, _} = Redix.command(conn, ~w(PUBLISH #{name} #{encoded})),
           do: :ok
    {:reply, result, state}
  end

  @impl true
  def terminate(_reason, %State{conn: conn}) do
    Redix.stop(conn)
    :ok
  end
end
