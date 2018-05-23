defmodule Yggdrasil.Subscriber.Adapter.Redis do
  @moduledoc """
  Yggdrasil subscriber adapter for Redis. The name of the channel must be a
  binary e.g:

  Subscription to channel:

  ```
  iex(2)> channel = %Yggdrasil.Channel{name: "redis_channel", adapter: :redis}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: "redis_channel", (...)}}
  ```

  Publishing message:

  ```
  iex(5)> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  Subscriber receiving message:

  ```
  iex(6)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: "redis_channel", (...)}, "foo"}
  ```

  The subscriber can also unsubscribe from the channel:

  ```
  iex(7)> Yggdrasil.unsubscribe(channel)
  :ok
  iex(8)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{name: "redis_channel", (...)}}
  ```
  """
  use GenServer

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend
  alias Yggdrasil.Settings

  defstruct [:publisher, :channel, :conn]
  alias __MODULE__, as: State

  ############
  # Client API

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

  #####################
  # GenServer callbacks

  @doc false
  def init(%State{channel: %Channel{name: name} = channel} = state) do
    options = redis_options(channel)
    {:ok, conn} = Redix.PubSub.start_link(options)
    state = %State{state | conn: conn}
    :ok = Redix.PubSub.psubscribe(conn, name, self())
    Logger.debug(fn -> "Started #{__MODULE__} for #{inspect channel}" end)
    {:ok, state}
  end

  @doc false
  def handle_info(
    {:redix_pubsub, _, :psubscribed, %{pattern: _}},
    %State{channel: %Channel{} = channel} = state
  ) do
    Logger.debug(fn ->
      "#{__MODULE__} connected to Redis #{inspect channel}"
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
  def terminate(:normal, %State{channel: channel, conn: conn}) do
    Redix.PubSub.stop(conn)
    Backend.disconnected(channel)
    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect channel}"
    end)
  end
  def terminate(reason, %State{channel: channel, conn: conn}) do
    Redix.PubSub.stop(conn)
    Backend.disconnected(channel)
    Logger.debug(fn ->
      "Stopped #{__MODULE__} for #{inspect channel} due to #{inspect reason}"
    end)
  end

  #########
  # Helpers

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
