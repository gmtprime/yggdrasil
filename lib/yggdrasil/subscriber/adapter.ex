defmodule Yggdrasil.Subscriber.Adapter do
  @moduledoc """
  Subscriber adapter behaviour.
  """
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry, as: Reg

  @doc """
  Callback to start a subscriber with a `channel`, a `publisher` and some
  `GenServer` `options`.
  """
  @callback start_link(
    Channel.t() :: atom(),
    publisher :: term(),
    options :: GenServer.options()
  ) :: GenServer.on_start()

  @doc """
  Use to implement `Yggdrasil.Subscriber.Adapter` behaviour.
  """
  defmacro __using__(_) do
    quote do
      @behaviour Yggdrasil.Subscriber.Adapter
    end
  end

  @doc """
  Generic subscriber adapter starter that receives a `channel`, a `publisher`
  and an optional `GenServer` options.
  """
  @spec start_link(
    Channel.t(),
    term()
  ) :: GenServer.on_start()
  @spec start_link(
    Channel.t(),
    term(),
    GenServer.options()
  ) :: GenServer.on_start()
  def start_link(channel, publisher, options \\ [])

  def start_link(
    %Channel{adapter: adapter} = channel,
    publisher,
    options
  ) do
    with {:ok, module} <- Reg.get_subscriber_module(adapter) do
      module.start_link(channel, publisher, options)
    end
  end

  @doc """
  Generic subscriber adapter stopper that receives the `pid`.
  """
  @spec stop(GenServer.name()) :: :ok
  def stop(pid) do
    GenServer.stop(pid)
  end
end
