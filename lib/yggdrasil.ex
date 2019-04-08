defmodule Yggdrasil do
  @moduledoc """
  > *Yggdrasil* is an immense mythical tree that connects the nine worlds in
  > Norse cosmology.

  `Yggdrasil` is an agnostic publisher/subscriber:

  - Multi-node pubsub.
  - Simple API (`subscribe/1`, `unsubscribe/1`, `publish/2`).
  - `GenServer` wrapper for handling subscriber events easily.
  - Several fault tolerant adapters (RabbitMQ, Redis, PostgreSQL, GraphQL,
  Ethereum).

  ## Small Example

  The following example uses the Elixir distribution to send the messages:

  ```elixir
  iex(1)> Yggdrasil.subscribe(name: "my_channel")
  iex(2)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{(...)}}
  ```

  and to publish a for the subscribers:

  ```elixir
  iex(3)> Yggdrasil.publish([name: "my_channel"], "message")
  iex(4)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{(...)}, "message"}
  ```

  When the subscriber wants to stop receiving messages, then it can unsubscribe
  from the channel:

  ```elixir
  iex(5)> Yggdrasil.unsubscribe(name: "my_channel")
  iex(6)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{(...)}}
  ```

  Though a `GenServer` can be used to receive these messages, this module also
  implements a behaviour for handling events e.g:

  ```
  defmodule Subscriber do
    use Yggdrasil

    def start_link do
      channel = [name: "my_channel"]
      Yggdrasil.start_link(__MODULE__, [channel])
    end

    def handle_event(_channel, message, _state) do
      IO.inspect message
      {:ok, nil}
    end
  end
  ```

  The previous `Yggdrasil` subscriber would subscribe to `[name: "my_channel"]`
  and print every message it receives from it.
  """
  use GenServer

  alias Yggdrasil.Backend
  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher
  alias Yggdrasil.Publisher.Generator, as: PublisherGen
  alias Yggdrasil.Registry
  alias Yggdrasil.Subscriber.Generator, as: SubscriberGen

  ######################
  # Subscriber functions

  @doc """
  Subscribes to a `channel`.
  """
  @spec subscribe(map() | Keyword.t() | Channel.t()) :: :ok | {:error, term()}
  def subscribe(channel)

  def subscribe(channel) do
    with {:ok, full_channel} <- gen_channel(channel),
         :ok <- Backend.subscribe(full_channel) do
      SubscriberGen.subscribe(full_channel)
    end
  end

  @doc """
  Unsubscribes from a `channel`.
  """
  @spec unsubscribe(map() | Keyword.t() | Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(channel)

  def unsubscribe(channel) do
    with {:ok, full_channel} <- gen_channel(channel),
         :ok <- Backend.unsubscribe(full_channel) do
      SubscriberGen.unsubscribe(full_channel)
    end
  end

  #####################
  # Publisher functions

  @doc """
  Publishes a `message` in a `channel` with some optional `options`.
  """
  @spec publish(map() | Keyword.t() | Channel.t(), term()) ::
          :ok | {:error, term()}
  @spec publish(map() | Keyword.t() | Channel.t(), term(), Keyword.t()) ::
          :ok | {:error, term()}
  def publish(channel, message, options \\ [])

  def publish(channel, message, options) do
    with {:ok, full_channel} <- gen_channel(channel),
         {:ok, _} <- PublisherGen.start_publisher(PublisherGen, full_channel) do
      Publisher.publish(full_channel, message, options)
    end
  end

  ###################
  # Channel functions

  @doc """
  Creates a channel from `data` where data is a map or a `Keyword` list.
  """
  @spec gen_channel(map() | Keyword.t() | Channel.t()) ::
          {:ok, Channel.t()} | {:error, term()}
  def gen_channel(data)

  def gen_channel(%Channel{} = channel) do
    Registry.get_full_channel(channel)
  end

  def gen_channel(data) when is_list(data) or is_map(data) do
    Channel
    |> struct(data)
    |> gen_channel()
  end

  def gen_channel(_) do
    {:error, "Bad channel"}
  end

  ###########
  # Callbacks

  @doc """
  Callback to initialize an `Yggdrasil`.
  """
  @callback init(args) ::
              {:subscribe, [Channel.t()], state}
              | {:stop, reason}
              when args: term, reason: term, state: term

  @doc """
  Callback to handle connection to channels.
  """
  @callback handle_connect(Channel.t(), state) ::
              {:ok, state}
              | {:subscribe, [Channel.t()], state}
              | {:unsubscribe, [Channel.t()], state}
              | {:stop, reason, state}
              when state: term(), reason: term()

  @doc """
  Callback to handle disconnections from a channel.
  """
  @callback handle_disconnect(Channel.t(), state) ::
              {:ok, state}
              | {:subscribe, [Channel.t()], state}
              | {:unsubscribe, [Channel.t()], state}
              | {:stop, reason, state}
              when state: term(), reason: term()

  @doc """
  Callback to handle incoming messages from a channel.
  """
  @callback handle_event(Channel.t(), message, state) ::
              {:ok, state}
              | {:subscribe, [Channel.t()], state}
              | {:unsubscribe, [Channel.t()], state}
              | {:stop, reason, state}
              when message: term(), state: term(), reason: term()

  @doc """
  Callback to handle `Yggdrasil` termination.
  """
  @callback terminate(reason, state) ::
              term() when state: term(), reason: term()

  ######################
  # Behaviour public API

  @doc """
  Starts an `Yggdrasil` given a `module`, `args` and some optional
  `options`.
  """
  @spec start_link(module(), term()) :: GenServer.on_start()
  @spec start_link(module(), term(), GenServer.options()) ::
          GenServer.on_start()
  def start_link(module, args, options \\ []) do
    GenServer.start_link(__MODULE__, [module, args], options)
  end

  @doc """
  Stops a `server` given optional `reason` and `timeout`.
  """
  @spec stop(GenServer.server()) :: :ok
  @spec stop(GenServer.server(), term()) :: :ok
  @spec stop(GenServer.server(), term(), :infinity | non_neg_integer()) :: :ok
  defdelegate stop(server, reason \\ :normal, timeout \\ :infinity),
    to: GenServer

  @doc false
  defmacro __using__(opts) do
    quote do
      @behaviour Yggdrasil

      @doc false
      def child_spec(init_arg) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]}
        }

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      @impl Yggdrasil
      def init(channels) when is_list(channels), do: {:subscribe, channels, nil}

      @impl Yggdrasil
      def handle_connect(_, state), do: {:ok, state}

      @impl Yggdrasil
      def handle_disconnect(_, state), do: {:ok, state}

      @impl Yggdrasil
      def handle_event(_, _, state), do: {:ok, state}

      @impl Yggdrasil
      def terminate(_, _), do: :ok

      defoverridable child_spec: 1,
                     init: 1,
                     handle_connect: 2,
                     handle_disconnect: 2,
                     handle_event: 3,
                     terminate: 2
    end
  end

  @doc false
  defstruct [:module, :state]
  alias __MODULE__, as: State

  @typedoc false
  @type t :: %State{
    module: module :: module(),
    state: state :: term()
  }

  #####################
  # GenServer callbacks

  @impl GenServer
  def init([module, args]) do
    case module.init(args) do
      {:subscribe, channels, internal} ->
        external = %State{module: module, state: internal}
        {:ok, external, {:continue, {:subscribe, channels}}}

      {:stop, _} = stop ->
        stop
    end
  end

  @impl GenServer
  def handle_continue({:subscribe, channels}, %State{} = external) do
    Enum.each(channels, &Yggdrasil.subscribe(&1))
    {:noreply, external}
  end

  def handle_continue({:unsubscribe, channels}, %State{} = external) do
    Enum.each(channels, &Yggdrasil.unsubscribe(&1))
    {:noreply, external}
  end

  @impl GenServer
  def handle_info({:Y_CONNECTED, channel}, %State{module: module} = external) do
    run(&module.handle_connect(channel, &1), external)
  end

  def handle_info({:Y_DISCONNECTED, channel}, %State{module: module} = external) do
    run(&module.handle_disconnect(channel, &1), external)
  end

  def handle_info({:Y_EVENT, channel, message}, %State{module: module} = external) do
    run(&module.handle_event(channel, message, &1), external)
  end

  @impl GenServer
  def terminate(reason, %State{module: module, state: internal}) do
    module.terminate(reason, internal)
  end

  # Runs callbacks
  @spec run((term -> {:ok, term()} | {:stop, term(), term()}), State.t()) ::
          {:noreply, State.t()} | {:stop, term(), State.t()}
  defp run(callback, %State{state: internal} = external) do
    case callback.(internal) do
      {:ok, internal} ->
        external = %State{external | state: internal}
        {:noreply, external}

      {:subscribe, channels, internal} ->
        external = %State{external | state: internal}
        {:noreply, external, {:continue, {:subscribe, channels}}}

      {:unsubscribe, channels, internal} ->
        external = %State{external | state: internal}
        {:noreply, external, {:continue, {:unsubscribe, channels}}}

      {:stop, reason, internal} ->
        external = %State{external | state: internal}
        {:stop, reason, external}
    end
  end
end
