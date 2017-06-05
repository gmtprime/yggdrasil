defmodule Yggdrasil.Subscriber.Adapter.Redis do
  @moduledoc """
  Yggdrasil subscriber adapter for Redis. The name of the channel must be a
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

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Settings

  defstruct [:publisher, :channel, :conn]
  alias __MODULE__, as: State

  #############################################################################
  # Client API.

  @doc """
  Starts a Redis distributor adapter in a `channel` with some distributor
  `publisher` and optionally `GenServer` `options`.
  """
  def start_link(%Channel{} = channel, publisher, options \\ []) do
    state = %State{publisher: publisher, channel: channel}
    GenServer.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops the Redis adapter with its `pid`.
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  #############################################################################
  # GenServer callbacks.

  @doc false
  def init(%State{channel: %Channel{name: name} = channel} = state) do
    options = redis_options(channel)
    {:ok, conn} = Redix.PubSub.start_link(options)
    state = %State{state | conn: conn}
    :ok = Redix.PubSub.psubscribe(conn, name, self())
    {:ok, state}
  end

  @doc false
  def handle_info(
    {:redix_pubsub, _, :psubscribed, %{pattern: _}},
    %State{channel: %Channel{name: name} = channel} = state
  ) do
    Logger.debug(fn ->
      "Connected to Redis #{inspect [channel: name]}"
    end)
    Backend.connected(channel)
    {:noreply, state}
  end
  def handle_info(
    {:redix_pubsub, _, :pmessage, %{channel: channel_name, payload: message}},
    %State{publisher: publisher} = state
  ) do
    Publisher.notify(publisher, channel_name, message)
    {:noreply, state}
  end
  def handle_info({:redix_pubsub, _, _, _}, %State{} = state) do
    {:noreply, state}
  end
  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(_reason, %State{conn: conn}) do
    Redix.PubSub.stop(conn)
    :ok
  end

  #############################################################################
  # Helpers.

  @doc false
  def redis_options(%Channel{namespace: namespace}) do
    options = get_namespace_options(namespace)
    connection_options = gen_connection_options(namespace)
    Keyword.merge(options, connection_options)
  end

  @doc false
  def get_namespace_options(Yggdrasil) do
    Skogsra.get_app_env(:yggdrasil, :redis, default: [])
  end
  def get_namespace_options(namespace) do
    Skogsra.get_app_env(:yggdrasil, :redis, default: [], domain: namespace)
  end

  @doc false
  def gen_connection_options(namespace) do
    [host: get_hostname(namespace),
     port: get_port(namespace),
     password: get_password(namespace),
     database: get_database(namespace)]
  end

  @doc false
  def get_value(namespace, key, default) do
    name = Settings.gen_env_name(namespace, key, "_YGGDRASIL_REDIS_")
    Skogsra.get_app_env(:yggdrasil, key,
      domain: [namespace, :redis],
      default: default,
      name: name
    )
  end

  @doc false
  def get_hostname(Yggdrasil) do
    Settings.yggdrasil_redis_hostname()
  end
  def get_hostname(namespace) do
    get_value(namespace, :hostname, Settings.yggdrasil_redis_hostname())
  end

  @doc false
  def get_port(Yggdrasil) do
    Settings.yggdrasil_redis_port()
  end
  def get_port(namespace) do
    get_value(namespace, :port, Settings.yggdrasil_redis_port())
  end

  @doc false
  def get_password(Yggdrasil) do
    Settings.yggdrasil_redis_password()
  end
  def get_password(namespace) do
    get_value(namespace, :password, Settings.yggdrasil_redis_password())
  end

  @doc false
  def get_database(Yggdrasil) do
    Settings.yggdrasil_redis_database()
  end
  def get_database(namespace) do
    get_value(namespace, :database, Settings.yggdrasil_redis_database())
  end
end
