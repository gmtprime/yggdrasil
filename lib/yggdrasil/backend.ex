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
  alias __MODULE__
  alias Phoenix.PubSub
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry
  alias Yggdrasil.Subscriber.Manager

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
  @callback connected(channel :: Channel.t(), pid :: atom() | pid()) ::
              :ok | {:error, term()}

  @doc """
  Callback to publish the disconnected message in the `channel`. Receives a
  `pid` in case the message shouldn't be broadcasted.
  """
  @callback disconnected(channel :: Channel.t(), pid :: atom() | pid()) ::
              :ok | {:error, term()}

  @doc """
  Callback to publish a `message` in a `channel` with some `metadata`.
  """
  @callback publish(
              channel :: Channel.t(),
              message :: term(),
              metadata :: term()
            ) :: :ok | {:error, term()}

  @doc """
  Macro for using `Yggdrasil.Backend`.

  The following are the available options:
  - `:name` - Name of the backend. Must be an atom.
  """
  defmacro __using__(options) do
    backend_alias =
      options[:name] || raise ArgumentError, message: "Backend not found"

    quote do
      @behaviour Yggdrasil.Backend

      use Task, restart: :transient

      @doc """
      Start task to register the backend in the `Registry`.
      """
      @spec start_link(term()) :: {:ok, pid()}
      def start_link(_) do
        Task.start_link(__MODULE__, :register, [])
      end

      @doc """
      Registers backend in `Registry`.
      """
      @spec register() :: :ok
      def register do
        name = unquote(backend_alias)

        Registry.register_backend(name, __MODULE__)
      end

      @doc """
      Subscribes to `channel`.
      """
      @spec subscribe(Channel.t()) :: :ok | {:error, term()}
      def subscribe(channel)

      def subscribe(%Channel{} = channel) do
        if Manager.subscribed?(channel) do
          :ok
        else
          channel_name = Backend.transform_name(channel)
          PubSub.subscribe(Yggdrasil.PubSub, channel_name)
        end
      rescue
        reason ->
          {:error, reason}
      end

      @doc """
      Unsubscribe to `channel`.
      """
      @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
      def unsubscribe(channel)

      def unsubscribe(%Channel{} = channel) do
        if Manager.subscribed?(channel) do
          channel_name = Backend.transform_name(channel)
          PubSub.unsubscribe(Yggdrasil.PubSub, channel_name)
        else
          :ok
        end
      rescue
        reason ->
          {:error, reason}
      end

      @doc """
      Broadcast a connection message in a `channel` and optionally to a `pid`.
      """
      @spec connected(Channel.t(), nil | pid()) :: :ok | {:error, term()}
      def connected(channel, pid)

      def connected(%Channel{} = channel, nil) do
        real_message = {:Y_CONNECTED, channel}
        channel_name = Backend.transform_name(channel)
        PubSub.broadcast(Yggdrasil.PubSub, channel_name, real_message)
      rescue
        reason ->
          {:error, reason}
      end

      def connected(%Channel{} = channel, pid) do
        real_message = {:Y_CONNECTED, channel}
        send(pid, real_message)
        :ok
      end

      @doc """
      Broadcast a disconnection message in a `channel` and optionally to a
      `pid`.
      """
      @spec disconnected(Channel.t(), nil | pid()) :: :ok | {:error, term()}
      def disconnected(channel, pid)

      def disconnected(%Channel{} = channel, nil) do
        real_message = {:Y_DISCONNECTED, channel}
        channel_name = Backend.transform_name(channel)
        PubSub.broadcast(Yggdrasil.PubSub, channel_name, real_message)
      rescue
        reason ->
          {:error, reason}
      end

      def disconnected(%Channel{} = channel, pid) do
        real_message = {:Y_DISCONNECTED, channel}
        send(pid, real_message)
        :ok
      end

      @doc """
      Broadcasts a `message` in a `channel` with some `metadata`.
      """
      @spec publish(Channel.t(), term(), term()) :: :ok | {:error, term()}
      def publish(channel, message, metadata)

      def publish(%Channel{} = channel, message, metadata) do
        complete_channel = %Channel{channel | metadata: metadata}
        real_message = {:Y_EVENT, complete_channel, message}
        channel_name = Backend.transform_name(channel)
        PubSub.broadcast(Yggdrasil.PubSub, channel_name, real_message)
      rescue
        reason ->
          {:error, reason}
      end

      defoverridable subscribe: 1,
                     unsubscribe: 1,
                     connected: 2,
                     disconnected: 2,
                     publish: 3
    end
  end

  @doc """
  Transforms name of the `channel` to a `binary`.
  """
  @spec transform_name(Channel.t()) :: binary()
  def transform_name(channel)

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
    with {:ok, module} <- Registry.get_backend_module(backend) do
      module.subscribe(channel)
    end
  end

  @doc """
  Generic unsubscriptions in a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
  def unsubscribe(channel)

  def unsubscribe(%Channel{backend: backend} = channel) do
    with {:ok, module} <- Registry.get_backend_module(backend) do
      module.unsubscribe(channel)
    end
  end

  @doc """
  Generic connected message sender to a `channel`. Optionally receives
  the `pid` of the specific subscriber.
  """
  @spec connected(Channel.t()) :: :ok | {:error, term()}
  @spec connected(Channel.t(), nil | pid()) :: :ok | {:error, term()}
  def connected(channel, pid \\ nil)

  def connected(%Channel{backend: backend} = channel, pid) do
    with {:ok, module} <- Registry.get_backend_module(backend) do
      module.connected(channel, pid)
    end
  end

  @doc """
  Generic disconnected message sender to a `channel`. Optionally receives
  the `pid` of the specific subscriber.
  """
  @spec disconnected(Channel.t()) :: :ok | {:error, term()}
  @spec disconnected(Channel.t(), nil | pid()) :: :ok | {:error, term()}
  def disconnected(channel, pid \\ nil)

  def disconnected(%Channel{backend: backend} = channel, pid) do
    with {:ok, module} <- Registry.get_backend_module(backend) do
      module.disconnected(channel, pid)
    end
  end

  @doc """
  Generic publish `message` in a `channel` with some optional `metadata`.
  """
  @spec publish(Channel.t(), term()) :: :ok | {:error, term()}
  @spec publish(Channel.t(), term(), term()) :: :ok | {:error, term()}
  def publish(channel, message, metadata \\ nil)

  def publish(%Channel{backend: backend} = channel, message, metadata) do
    with {:ok, module} <- Registry.get_backend_module(backend) do
      module.publish(channel, message, metadata)
    end
  end
end
