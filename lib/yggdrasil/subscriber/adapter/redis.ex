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
  use Yggdrasil.Subscriber.Adapter
  use GenServer

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Backend
  alias Yggdrasil.Subscriber.Publisher
  alias Yggdrasil.Settings, as: GlobalSettings
  alias Yggdrasil.Settings.Redis, as: Settings

  defstruct [:publisher, :channel, :conn]
  alias __MODULE__, as: State

  #####################
  # GenServer callbacks

  @impl true
  def init(%{channel: %Channel{} = channel} = arguments) do
    state = struct(State, arguments)
    options = redis_options(channel)
    {:ok, conn} = Redix.PubSub.start_link(options)
    state = %State{state | conn: conn}
    Logger.debug(fn -> "Started #{__MODULE__} for #{inspect channel}" end)
    {:ok, state, 0}
  end

  @impl true
  def handle_info(
    :timeout,
    %State{conn: conn, channel: %Channel{name: name}} = state
  ) do
    with true <- Process.alive?(conn),
         %Connection{backoff: nil} <- :sys.get_state(conn) do
      Redix.PubSub.psubscribe(conn, name, self())
      {:noreply, state}
    else
      false ->
        {:stop, {:error, "Redix process not alive"}, state}
      %Connection{} ->
        {:noreply, state, 5000}
    end
  end
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
  def handle_info(
    {:redix_pubsub, _, :disconnected, reason},
    %State{channel: channel} = state
  ) do
    Logger.warn(fn ->
      "#{__MODULE__} disconnected to Redis #{inspect channel} due to" <>
      " #{inspect reason}"
    end)
    Backend.disconnected(channel)
    {:noreply, state}
  end
  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  @impl true
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
    name = GlobalSettings.gen_env_name(namespace, key, "_YGGDRASIL_REDIS_")
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
