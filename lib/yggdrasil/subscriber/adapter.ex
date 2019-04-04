defmodule Yggdrasil.Subscriber.Adapter do
  @moduledoc """
  Subscriber adapter behaviour.
  """
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry

  @doc """
  Callback to start a subscriber with a `channel`, a `publisher` and some
  `GenServer` `options`.
  """
  @callback start_link(
              channel :: Channel.t(),
              options :: GenServer.options()
            ) :: GenServer.on_start()

  @doc """
  Use to implement `Yggdrasil.Subscriber.Adapter` behaviour.
  """
  defmacro __using__(_) do
    quote do
      @behaviour Yggdrasil.Subscriber.Adapter

      @doc """
      Starts #{__MODULE__} with a `channel and optional `options`.
      """
      @spec start_link(Channel.t()) :: GenServer.on_start()
      @spec start_link(Channel.t(), GenServer.options()) ::
              GenServer.on_start()
      @impl true
      def start_link(channel, options \\ [])

      def start_link(%Channel{} = channel, options) do
        GenServer.start_link(__MODULE__, %{channel: channel}, options)
      end

      defoverridable start_link: 1, start_link: 2
    end
  end

  @doc """
  Generic subscriber adapter starter that receives a `channel`, a `publisher`
  and an optional `GenServer` options.
  """
  @spec start_link(Channel.t()) :: GenServer.on_start()
  @spec start_link(Channel.t(), GenServer.options()) :: GenServer.on_start()
  def start_link(channel, options \\ [])

  def start_link(%Channel{adapter: adapter} = channel, options) do
    with {:ok, module} <- Registry.get_subscriber_module(adapter) do
      module.start_link(channel, options)
    end
  end

  @doc """
  Generic subscriber adapter stopper that receives the `pid` and optional
  `reason` and `timeout`.
  """
  @spec stop(pid() | GenServer.name()) :: :ok
  @spec stop(pid() | GenServer.name(), term()) :: :ok
  @spec stop(pid() | GenServer.name(), term(), :infinity | pos_integer()) :: :ok
  defdelegate stop(pid, reason \\ :normal, timeout \\ :infinity), to: GenServer
end
