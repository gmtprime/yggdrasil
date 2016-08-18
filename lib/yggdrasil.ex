defmodule Yggdrasil do
  @moduledoc """
  > *Yggdrasil* is an immense mythical tree that connects the nine worlds in
  > Norse cosmology.

  `Yggdrasil` manages subscriptions to channels/queues in several brokers with
  the possibility to add more. Simple Redis, RabbitMQ and PostgreSQL adapters
  are implemented. Message passing is done through
  [`YProcess`](https://github.com/gmtprime/y_process). `YProcess` allows to use
  `Phoenix.PubPub` as a pub/sub to distribute messages between processes.

  ## Example using Redis

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{channel: "redis_channel", decoder: Yggdrasil.Decoder.Default.Redis}
  iex(2)> Yggdrasil.subscribe(channel)
  ```

  > By default, the Redis adapter connects to `"redis://localhost:6379"`.

  Then in redis:

  ```
  127.0.0.1:6379> PUBLISH "redis_channel" "hello"
  (integer) (1)
  ```

  And finally if you flush in your `iex` you'll see the message received
  by the Elixir shell:

  ```elixir
  iex(3> flush()
  {:Y_CAST_EVENT, "redis_channel", "hello"}
  :ok
  ```

  Things to note:

    * Every message coming from a broker (Redis, RabbitMQ, PostgreSQL) will be
    like:

    ```elixir
    {:Y_CAST_EVENT, channel, message}
    ```

    * The process calling `Yggdrasil.subscribe/1` will be the one that subscribes
    to the channel

  ## Example using RabbitMQ

  First you must have the RabbitMQ exchange created. Otherwise the client won't
  connect. Channels for the RabbitMQ adapter use a tupple instead of a string:

  ```elixir
  {"exchange_name", "routing_key"}
  ```

  where the exchange should be of type `:topic`. This would allow you to connect
  to a channel using a routing key like `"*.error"` where messages with routing
  keys like `"miami.error"` and `"barcelona.error"` would match the routing key
  of the `Yggdrasil` channel.

  Let's say you want to connect to the exchange `"amq.topic"` (created by default)
  with the previous routing key (`"*.error"`) where you'll receive errors from all
  the servers:

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{channel: {"amq.topic", "*.error"}, decoder: Yggdrasil.Decoder.Default.RabbitMQ}
  iex(2)> Yggdrasil.subscribe(channel)
  ```

  > By default, the RabbitMQ adapter connects to
  > `"amqp://guest:guest@localhost:5672/"`

  Then using `AMQP` library, publish some messages in RabbitMQ:

  ```elixir
  iex(3)> options = Application.get_env(:yggdrasil, :rabbitmq, [])
  iex(4)> {:ok, conn} = AMQP.Connection.open(options)
  iex(5)> {:ok, chan} = AMQP.Channel.open(conn)
  iex(6)> AMQP.Basic.publish(chan, "amq.topic", "miami.error", "Error from Miami")
  iex(7)> AMQP.Basic.publish(chan, "amq.topic", "barcelona.error", "Error from Barcelona")
  ```

  And finally if you flush in your `iex` you'll see the message received
  by the Elixir shell:

  ```elixir
  iex(8> flush()
  {:Y_CAST_EVENT, {"amq.topic", "*.error"}, "Error from Miami"}
  {:Y_CAST_EVENT, {"amq.topic", "*.error"}, "Error from Barcelona"}
  :ok
  ```

  ## Example using PostgreSQL

  For this example, it's necessary to provide a valid configuration for the
  PostgreSQL adapter i.e:

  ```elixir
  use Mix.Config

  config :yggdrasil,
    postgres: [hostname: "localhost",
              port: 5432,
              username: "yggdrasil_test",
              password: "yggdrasil_test",
              database: "yggdrasil_test"]
  ```

  This will connect the adapter to the database `yggdrasil_test` with the user
  `yggdrasil_test` and the password `yggdrasil_test` on `localhost:5432`.

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{channel: "postgres_channel", decoder: Yggdrasil.Decoder.Default.Postgres}
  iex(2)> Yggdrasil.subscribe(channel)
  ```

  Then in PostgreSQL:

  ```
  yggdrasil_test=> NOTIFY postgres_channel, 'hello'
  NOTIFY
  ```

  And finally if you flush in `iex` you'll see the message received by the Elixir
  shell:

  ```elixir
  iex(8> flush()
  {:Y_CAST_EVENT, "postgres_channel", "hello"}
  :ok
  ```

  ## Example using GenServer

  Any of the previous examples can be wrapped inside a `GenServer`, in this case
  it is Redis:

  ```elixir
  defmodule Subscriber do
    use GenServer

    ###################
    # Client functions.

    def start_link(channel, opts \\ []) do
      GenServer.start_link(__MODULE__, channel, opts)
    end

    def stop(subscriber, reason \\ :normal) do
      GenServer.stop(subscriber, reason)
    end

    ######################
    # GenServer callbacks.

    def init(channel) do
      Yggdrasil.subscribe(channel)
      {:ok, channel}
    end

    def handle_info({:Y_CAST_EVENT, channel, message}, state) do
      IO.inspect %{channel: channel, message: message}
      {:noreply, state}
    end

    def terminate(_reason, channel) do
      Yggdrasil.unsubscribe(channel)
      :ok
    end
  end
  ```

  So in `iex`:

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{channel: "redis_channel", decoder: Yggdrasil.Decoder.Default.Redis}
  iex(2)> {:ok, subscriber} = Subscriber.start_link(channel)
  iex(3)>
  ```

  Again in Redis:

  ```
  127.0.0.1:6379> PUBLISH "redis_channel" "hello"
  (integer) (1)
  ```

  And finally you'll see in your `iex` the following:

  ```elixir
  %{channel: "redis_channel", message: "hello"}
  iex(3)>
  ```

  ## Example using YProcess

  `YProcess` is a `GenServer` wrapper with pubsub capabilities and it has
  great sinergy with `Yggdrasil`. The previous example implemented with
  `YProcess` would be:

  ```elixir
  defmodule YSubscriber do
    use YProcess, backend: Yggdrasil.Backend

    ###################
    # Client functions.

    def start_link(channel, opts \\ []) do
      YProcess.start_link(__MODULE__, channel, opts)
    end

    def stop(subscriber, reason \\ :normal) do
      YProcess.stop(subscriber, reason)
    end

    #####################
    # YProcess callbacks.

    def init(channel) do
      {:join, [channel], channel}
    end

    def handle_event(channel, message, state) do
      IO.inspect %{channel: channel, message: message}
      {:noreply, state}
    end
  end
  ```

  So in `iex`:

  ```elixir
  iex(1)> channel = %Yggdrasil.Channel{channel: "redis_channel", decoder: Yggdrasil.Decoder.Default.Redis}
  iex(2)> {:ok, y_subscriber} = YSubscriber.start_link(channel)
  iex(3)>
  ```

  Again in Redis:

  ```
  127.0.0.1:6379> PUBLISH "redis_channel" "hello"
  (integer) (1)
  ```

  And finally you'll see in your `iex` the following:

  ```elixir
  %{channel: "redis_channel", message: "hello"}
  iex(3)>
  ```

  ## Yggdrasil Channels

  `Yggdrasil` channels have the name of the channel in the broker and the
  name of the module of the message decoder. A decoder module also defines
  which adapter should be used to connect to the channel.

  ```elixir
  %Yggdrasil.Channel{channel: "channel", decoder: Yggdrasil.Decoder.Default.Redis}
  ```
  The previous example will tell Yggdrasil to subscribe to the channel `"channel"`.
  The decoder module `Yggdrasil.Decoder.Default.Redis` defined Redis as the broker
  and does not change the message coming from Redis before sending it to the
  subscribers.

  ### Decoders

  The current `Yggdrasil` version has the following decoder modules:

    * `Yggdrasil.Decoder.Default`: Does nothing to the message and uses the
    `Yggdrasil.Adapter.Elixir`.
    * `Yggdrasil.Decoder.Default.Redis`: Does nothing to the message and uses the
    `Yggdrasil.Adapter.Redis`.
    * `Yggdrasil.Decoder.Default.RebbitMQ`: Does nothing to the message and uses the
    `Yggdrasil.Adapter.RabbitMQ`.
    * `Yggdrasil.Decoder.Default.Postgres`: Does nothing to the message and uses the
    `Yggdrasil.Adapter.Postgres`.

  > For more information about adapters, see the Adapters section.

  To implement a decoder is necessary to implement the `decode/2` callback for
  `Yggdrasil.Decoder` behaviour, i.e. subscribe to a Redis channel `"test"` that
  publishes JSON. The subscribers must receive a map instead of a string with the
  JSON.

  ```elixir
  defmodule CustomDecoder do
    use Yggdrasil.Decoder, adapter: Yggdrasil.Adapter.Redis

    def decode(_channel, message) do
      Poison.decode!(message)
    end
  end
  ```

  > **Important**: The channel received by the `decode/2` function might be
  > different than the channel the client is subscribed. For example, with the
  > RabbitMQ adapter you can subscribe to the channel `{"amq.topic", "*.error"}`,
  > but if the routing key of the received message is `"barcelona.error"`, then
  > the channel received by this function will be `{"amq.topic", "barcelona.error"}`
  > instead of `{"amq.topic", "*.error"}`. It is a good idea to include this
  > channel to the decoded message in order to know its real procedence.

  To subscribe to this channel, clients must use the following `Yggdrasil` channel:

  ```elixir
  %Yggdrasil.Channel{channel: "test", decoder: CustomDecoder}
  ```

  ### Adapters

  The current `Yggdrasil` version has the following adapters:

    * `Yggdrasil.Adapter.Elixir`: Message distribution using Elixir messages.
    * `Yggdrasil.Adapter.Redis`: Messages come from a Redis channel.
    * `Yggdrasil.Adapter.RabbitMQ`: Messages come from a RabbitMQ queue. A
    `channel` is a tuple that contains the exchange and the routing key:
    `{exchange, routing_key}`.
    * `Yggdrasil.Adapter.Postgres`: Messages come from the notifies of a
    PostgreSQL database.

  Also the function `Yggdrasil.publish/2` is used to simulate published messages
  by any of the brokers.

  To implement a new adapter is necessary to use a `GenServer` or any wrapper over
  `GenServer`. For more information, see the source code of any of the implemented
  adapters.

  ## Installation

  `Yggdrasil` is available as a Hex package. To install, add it to your
  dependencies in your `mix.exs` file:

  ```elixir
  def deps do
    [{:amqp_client, git: "https://github.com/jbrisbin/amqp_client.git", override: true},
    {:yggdrasil, "~> 2.0.5"}]
  end
  ```

  > Overriding `:amqp_client` dependency is necessary in order to use `Yggdrasil`
  > with Erlang 19.

  and ensure `Yggdrasil` is started before your application:

  ```elixir
  def application do
    [applications: [:yggdrasil]]
  end
  ```

  ## Configuration

  `Yggdrasil` uses `YProcess` as a means to distribute the messages. So it is
  necessary to provide a configuration for `YProcess` if you want to use, for
  example, `Phoenix.PubSub` as your pubsub, i.e:

  ```elixir
  use Mix.Config

  config :y_process,
    backend: YProcess.Backend.PhoenixPubSub,
    name: Yggdrasil.PubSub,
    adapter: Phoenix.PubSub.PG2,
    options: [pool_size: 10]
  ```
  by default, `YProcess` will use `YProcess.Backend.PG2` as default backend.

  For `Yggdrasil`, there's only one general configuration parameter which is
  the process name registry. By default, it uses `ExReg`, which is a simple but
  rich process name registry. It is possible to use another one like `:gproc`.

  ```elixir
  use Mix.Config

  config :yggdrasil,
    registry: :gproc
  ```

  Specific configuration parameters are as follows:

    * To configure `Yggdrasil` with the provided Redis adapter
    (`Yggdrasil.Adapter.Redis`):

    ```elixir
    use Mix.Config

    config :yggdrasil,
      redis: [host: "localhost",
              port: 6379,
              password: "my password"]
    ```
    The default Redis adapter uses `Redix`, so the configuration parameters have
    the same name as the ones in `Redix`. By default connects to `redis://localhost`.

    * To configure `Yggdrasil` with the provided RabbitMQ adapter
    (`Yggdrasil.Adapter.RabbitMQ`):

    ```elixir
    use Mix.Config

    config :yggdrasil,
      rabbitmq: [host: "localhost",
                port: 5672,
                username: "guest",
                password: "guest",
                virtual_host: "/"]
    ```
    The default RabbitMQ adapter uses `AMQP`, so the configuration parameters have
    the same name as the ones in `AMQP`. By default connects to
    `amqp://guest:guest@localhost/`

    * To configure `Yggdrasil` with the provided PostgreSQL adapter
    (`Yggdrasil.Adapter.Postgres`):

    ```elixir
    use Mix.Config

    config :yggdrasil,
      postgres: [hostname: "localhost",
                port: 5432,
                username: "postgres",
                password: "postgres",
                database: "yggdrasil"]
    ```
    The default PostgreSQL adapter uses `Postgrex`, so the configuration parameters
    have the same name as the ones in `Postgrex`.
  """
  use Application

  alias Yggdrasil.Channel

  @backend YProcess.Backend.PG2
  @generator Yggdrasil.Publisher.Generator
  @broker Yggdrasil.Broker

  #############
  # Client API.

  @doc """
  Subscribes to a `channel`.
  """
  def subscribe(channel) do
    Yggdrasil.Backend.join(channel, self())
  end

  @doc """
  Unsubscribe from a `channel`.
  """
  def unsubscribe(channel) do
    Yggdrasil.Backend.leave(channel, self())
  end

  @doc """
  Emits a `message` in a `channel`. Bypasses the adapter.
  """
  def publish(%Channel{channel: channel, decoder: decoder}, message) do
    registry = apply(@generator, :get_registry, [])
    publisher = {:via, registry, {Yggdrasil.Publisher, channel, decoder}}
    Yggdrasil.Publisher.sync_notify(publisher, channel, message)
  end
  def publish(channel, message) do
    Yggdrasil.Backend.emit(channel, message)
  end

  #################
  # Version checks.

  require Logger
  @version Mix.Project.config[:version]

  ##
  # Current Yggdrasil version.
  defp current_version, do: @version

  ##
  # Checks version.
  defp check_version() do
    Hex.start()
    Hex.Utils.ensure_registry!()

    all_versions =
      :yggdrasil
      |> Atom.to_string()
      |> Hex.Registry.get_versions()
    current = current_version()

    if should_update?(all_versions, current) do
      latest = latest_version(all_versions, current)
      Logger.warn("A new Yggdrasil version is available (#{latest} > #{current}).")
    else
      Logger.debug("Using the lastest version of Yggdrasil (#{current}).")
    end
  end

  ##
  # Whether Yggdrasil should be updated or not.
  defp should_update?(all_versions, current) do
    latest = latest_version(all_versions, current)
    Hex.Version.compare(current, latest) == :lt
  end

  ##
  # Gets the latest version.
  defp latest_version(all_versions, default) do
    including_pre_versions? = pre_version?(default)
    latest = highest_version(all_versions, including_pre_versions?)
    latest || default
  end

  ##
  # Whether it allows previous versions or not.
  defp pre_version?(version) do
    {:ok, version} = Hex.Version.parse(version)
    version.pre != []
  end

  ##
  # Gets the highest version.
  defp highest_version(versions, including_pre_versions?) do
    if including_pre_versions? do
      versions |> List.last
    else
      versions |> Enum.reject(&pre_version?/1) |> List.last
    end
  end

  ##############
  # Application.

  ##
  # Monitors table.
  defp get_monitors_table do
    :ets.new(:monitors, [:set, :public, write_concurrency: false,
                         read_concurrency: true])
  end

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    check_version()

    monitors = get_monitors_table()

    children = [
      supervisor(@generator, [[name: @generator]]),
      worker(@broker, [@generator, monitors, [name: @broker]])
    ] 

    children = case Application.get_env(:y_process, :backend, @backend) do
      YProcess.Backend.PG2 -> children
      YProcess.Backend.PhoenixPubSub ->
        [supervisor(YProcess.PhoenixPubSub, []) | children]
    end

    opts = [strategy: :rest_for_one, name: Yggdrasil.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
