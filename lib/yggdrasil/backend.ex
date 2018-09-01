defmodule Yggdrasil.Backend do
  @moduledoc """
  Backend behaviour that defines how to subscribe, unsubscribe and publish as
  well as send messages of connection and disconnection to subscribers.

  By default, the implementation uses `Phoenix.PubSub` as backend.

  ## Backend alias

  When defining backends it is possible to define aliases for the module
  as follows:

  ```
  defmodule Yggdrasil.Backend.MyBackend do
    use Yggdrasil.Backend, name: :my_backend

    (... behaviour implementation ...)
  end
  ```

  And adding the following to our application supervision tree:

  ```
  Supervisor.start_link([
    {Yggdrasil.Backend.MyBackend, []}
    ...
  ])
  ```

  This will allow you to use the following as a `Channel` to subscribe and
  publish:

  ```
  %Channel{name: "my_channel", backend: :my_backend}
  ```
  """
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry, as: Reg

  @doc """
  Callback to define the subscription method. Receives the `channel`.
  """
  @callback subscribe(channel :: Channel.t()) :: :ok | {:error, term()}

  @doc """
  Callback to define the unsubscription method. Receives the `channel`.
  """
  @callback unsubscribe(channel :: Channel.t()) :: :ok | {:error, term()}

  @doc """
  Callback to publish the connected message in the `channel`. Receives a `pid`
  in case the message shouldn't be broadcasted.
  """
  @callback connected(
    channel :: Channel.t(),
    pid :: atom() | pid()
  ) :: :ok | {:error, term()}

  @doc """
  Callback to publish the disconnected message in the `channel`. Receives a
  `pid` in case the message shouldn't be broadcasted.
  """
  @callback disconnected(
    channel :: Channel.t(),
    pid :: atom() | pid()
  ) :: :ok | {:error, term()}

  @doc """
  Callback to publish a `message` in a `channel`.
  """
  @callback publish(
    channel :: Channel.t(),
    message :: term()
  ) :: :ok | {:error, term()}

  @doc """
  Macro for using `Yggdrasil.Backend`.

  The following are the available options:
  - `:name` - Name of the backend. Must be an atom.
  """
  defmacro __using__(options) do
    backend_alias = Keyword.get(options, :name)
    quote do
      @behaviour Yggdrasil.Backend
      alias Phoenix.PubSub
      alias Yggdrasil.Channel
      alias Yggdrasil.Settings
      alias Yggdrasil.Subscriber.Manager
      alias Yggdrasil.Registry, as: Reg

      use Task, restart: :transient

      @doc false
      def start_link(_) do
        Task.start_link(__MODULE__, :register, [])
      end

      @doc false
      def register do
        name = unquote(backend_alias)
        with :ok <- Reg.register_backend(name, __MODULE__) do
          :ok
        else
          :error ->
            exit(:error)
        end
      end

      @doc false
      def subscribe(%Channel{} = channel) do
        if not Manager.subscribed?(channel) do
          pubsub = Settings.yggdrasil_pubsub_name()
          channel_name = Yggdrasil.Backend.transform_name(channel)
          PubSub.subscribe(pubsub, channel_name)
        else
          :ok
        end
      end

      @doc false
      def unsubscribe(%Channel{} = channel) do
        if Manager.subscribed?(channel) do
          pubsub = Settings.yggdrasil_pubsub_name()
          channel_name = Yggdrasil.Backend.transform_name(channel)
          PubSub.unsubscribe(pubsub, channel_name)
          disconnected(channel, self())
        else
          :ok
        end
      end

      @doc false
      def connected(%Channel{} = channel, nil) do
        pubsub = Settings.yggdrasil_pubsub_name()
        real_message = {:Y_CONNECTED, channel}
        channel_name = Yggdrasil.Backend.transform_name(channel)
        PubSub.broadcast(pubsub, channel_name, real_message)
      end
      def connected(%Channel{} = channel, pid) do
        real_message = {:Y_CONNECTED, channel}
        send pid, real_message
        :ok
      end

      @doc false
      def disconnected(%Channel{} = channel, nil) do
        pubsub = Settings.yggdrasil_pubsub_name()
        real_message = {:Y_DISCONNECTED, channel}
        channel_name = Yggdrasil.Backend.transform_name(channel)
        PubSub.broadcast(pubsub, channel_name, real_message)
      end
      def disconnected(%Channel{} = channel, pid) do
        real_message = {:Y_DISCONNECTED, channel}
        send pid, real_message
        :ok
      end

      @doc false
      def publish(%Channel{} = channel, message) do
        pubsub = Settings.yggdrasil_pubsub_name()
        real_message = {:Y_EVENT, channel, message}
        channel_name = Yggdrasil.Backend.transform_name(channel)
        PubSub.broadcast(pubsub, channel_name, real_message)
      end

      defoverridable [
        subscribe: 1,
        unsubscribe: 1,
        connected: 2,
        disconnected: 2,
        publish: 2
      ]
    end
  end

  @doc false
  @spec transform_name(Channel.t()) :: binary()
  def transform_name(%Channel{} = channel) do
    channel
    |> :erlang.phash2()
    |> Integer.to_string()
  end

  @doc """
  Generic subscription in a `channel`.
  """
  @spec subscribe(Channel.t()) :: :ok | {:error, term()}
  def subscribe(channel)

  def subscribe(%Channel{backend: backend} = channel) do
    with {:ok, module} <- Reg.get_backend_module(backend) do
      module.subscribe(channel)
    end
  end

  @doc """
  Generic unsubscriptions in a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(channel)

  def unsubscribe(%Channel{backend: backend} = channel) do
    with {:ok, module} <- Reg.get_backend_module(backend) do
      module.unsubscribe(channel)
    end
  end

  @doc """
  Generic connected message sender to a `channel`. Optionally receives
  the `pid` of the specific subscriber.
  """
  @spec connected(Channel.t()) :: :ok | {:error, term()}
  def connected(channel, pid \\ nil)

  def connected(%Channel{backend: backend} = channel, pid) do
    with {:ok, module} <- Reg.get_backend_module(backend) do
      module.connected(channel, pid)
    end
  end

  @doc """
  Generic disconnected message sender to a `channel`. Optionally receives
  the `pid` of the specific subscriber.
  """
  @spec disconnected(Channel.t()) :: :ok | {:error, term()}
  def disconnected(channel, pid \\ nil)

  def disconnected(%Channel{backend: backend} = channel, pid) do
    with {:ok, module} <- Reg.get_backend_module(backend) do
      module.disconnected(channel, pid)
    end
  end

  @doc """
  Generic publish `message` in a `channel`.
  """
  @spec publish(Channel.t, term()) :: :ok | {:error, term()}
  def publish(channel, message)

  def publish(%Channel{backend: backend} = channel, message) do
    with {:ok, module} <- Reg.get_backend_module(backend) do
      module.publish(channel, message)
    end
  end
end
