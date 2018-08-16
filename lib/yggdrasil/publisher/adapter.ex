defmodule Yggdrasil.Publisher.Adapter do
  @moduledoc """
  Publisher adapter behaviour.
  """
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry, as: Reg

  @doc """
  Callback to start a publisher with a `namespace` and some `GenServer`
  `options`.
  """
  @callback start_link(
    namespace :: atom(),
    options :: GenServer.options()
  ) :: GenServer.on_start()

  @doc """
  Use to implement `Yggdrasil.Publisher.Adapter` behaviour.
  """
  defmacro __using__(_) do
    quote do
      @behaviour Yggdrasil.Publisher.Adapter
    end
  end

  @doc """
  Generic publisher adapter starter that receives a `channel` and an optional
  `GenServer` options.
  """
  @spec start_link(Channel.t()) :: GenServer.on_start()
  @spec start_link(
    Channel.t(),
    GenServer.options()
  ) :: GenServer.on_start()
  def start_link(channel, options \\ [])

  def start_link(
    %Channel{
      adapter: adapter,
      namespace: namespace
    },
    options
  ) do
    with {:ok, module} <- Reg.get_publisher_module(adapter) do
      module.start_link(namespace, options)
    end
  end

  @doc """
  Generic publisher adapter stopper that receives the `pid`.
  """
  @spec stop(GenServer.name()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end
end
