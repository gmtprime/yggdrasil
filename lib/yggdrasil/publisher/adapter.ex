defmodule Yggdrasil.Publisher.Adapter do
  @moduledoc """
  Publisher adapter behaviour.
  """
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry

  @doc """
  Callback to start a publisher with a `namespace` and some `GenServer`
  `options`.
  """
  @callback start_link(
              namespace :: atom(),
              options :: GenServer.options()
            ) :: GenServer.on_start()

  @doc """
  Callback for publishing a `message` in a `channel` using a `publisher`.
  """
  @callback publish(
              publisher :: GenServer.server(),
              channel :: Channel.t(),
              message :: term()
            ) :: :ok | {:error, term()}

  @doc """
  Publishes a `message` in a `channel` using a `publisher` and some `options`.
  """
  @callback publish(
              publisher :: GenServer.server(),
              channel :: Channel.t(),
              message :: term(),
              options :: Keyword.t()
            ) :: :ok | {:error, term()}

  @doc """
  Use to implement `Yggdrasil.Publisher.Adapter` behaviour.
  """
  defmacro __using__(_) do
    quote do
      @behaviour Yggdrasil.Publisher.Adapter

      @doc """
      Starts a publisher adapter for an adapter given a `namespace`.
      Optionally, receives `GenServer` `options`.
      """
      @spec start_link(atom(), GenServer.options()) :: GenServer.options()
      @impl true
      def start_link(namespace, options \\ [])

      def start_link(namespace, options) do
        GenServer.start_link(__MODULE__, namespace, options)
      end

      @doc """
      Publishes a `message` in a `channel` using a `publisher`.
      """
      @spec publish(GenServer.server(), Channel.t(), term()) ::
              :ok | {:error, term()}
      @spec publish(GenServer.server(), Channel.t(), term(), Keyword.t()) ::
              :ok | {:error, term()}
      @impl true
      def publish(publisher, channel, message, options \\ [])

      def publish(publisher, %Channel{} = channel, message, _options) do
        GenServer.call(publisher, {:publish, channel, message})
      end

      defoverridable start_link: 1,
                     start_link: 2,
                     publish: 3,
                     publish: 4
    end
  end

  @doc """
  Generic publisher adapter starter that receives a `channel` and an optional
  `GenServer` options.
  """
  @spec start_link(Channel.t()) :: GenServer.on_start()
  @spec start_link(Channel.t(), GenServer.options()) :: GenServer.on_start()
  def start_link(channel, options \\ [])

  def start_link(
        %Channel{
          adapter: adapter,
          namespace: namespace
        },
        options
      ) do
    with {:ok, module} <- Registry.get_publisher_module(adapter) do
      module.start_link(namespace, options)
    end
  end

  @doc """
  Generic publisher adapter publish function. Publisher a `message` in a
  `channel` using a `publisher` and some `options`.
  """
  @spec publish(GenServer.server(), Channel.t(), term(), Keyword.t()) ::
          :ok | {:error, term()}
  def publish(publish, channel, message, options)

  def publish(
        publisher,
        %Channel{adapter: adapter} = channel,
        message,
        options
      ) do
    with {:ok, module} <- Registry.get_publisher_module(adapter) do
      module.publish(publisher, channel, message, options)
    end
  end

  @doc """
  Generic publisher adapter stopper that receives the `pid`.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end
end
