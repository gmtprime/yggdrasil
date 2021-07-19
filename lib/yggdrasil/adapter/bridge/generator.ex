defmodule Yggdrasil.Adapter.Bridge.Generator do
  @moduledoc """
  This module generates supervised remote subscribers.
  """
  use DynamicSupervisor

  alias Yggdrasil.Adapter.Bridge.Subscriber
  alias Yggdrasil.Channel

  ############
  # Client API

  @doc """
  Starts a bridge subscriber generator with `Supervisor` `options`.
  """
  @spec start_link() :: Supervisor.on_start()
  @spec start_link([
          DynamicSupervisor.option() | DynamicSupervisor.init_option()
        ]) ::
          Supervisor.on_start()
  def start_link(options \\ []) do
    DynamicSupervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a bridge subscriber `generator`.
  """
  @spec stop(Supervisor.supervisor()) :: :ok
  def stop(generator) do
    for {_, pid, _, _} <- Supervisor.which_children(generator) do
      try do
        Subscriber.stop(pid)
      catch
        _, _ -> :ok
      end

      Supervisor.stop(generator)
    end

    :ok
  end

  @doc """
  Starts a bridge subscriber with a `channel` and remote `pid`.
  """
  @spec start_bridge(pid(), Channel.t(), Channel.t()) ::
          {:ok, pid()} | {:error, term()}
  def start_bridge(pid, local, remote)

  def start_bridge(pid, %Channel{} = local, %Channel{} = remote) do
    via_tuple = ExReg.local({Subscriber, pid, local, remote})

    spec = %{
      id: via_tuple,
      start: {Subscriber, :start_link, [pid, local, remote, [name: via_tuple]]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(__MODULE__, spec) do
      {:ok, _} = ok -> ok
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, _} = error -> error
    end
  end

  #####################
  # Supervisor callback

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
