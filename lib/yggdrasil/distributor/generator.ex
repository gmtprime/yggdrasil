defmodule Yggdrasil.Distributor.Generator do
  @moduledoc """
  Supervisor to generate distributors on demand.
  """
  use Supervisor
  alias Yggdrasil.Channel
  alias Yggdrasil.Settings

  @distributor Yggdrasil.Distributor
  @registry Settings.registry()

  #############################################################################
  # Client API.

  @doc """
  Starts a distributor generator with `Supervisor` `options`.
  """
  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a distributor `generator`.
  """
  def stop(generator) do
    for {_, pid, _, _} <- Supervisor.which_children(generator) do
      try do
        @distributor.stop(pid)
      catch
        _, _ -> :ok
      end
    end
    Supervisor.stop(generator)
  end

  @doc """
  Starts a distributor using the `generator` and the `channel` to identify
  the connection.
  """
  def start_distributor(generator, %Channel{} = channel) do
    name = {@distributor, channel}
    case @registry.whereis_name(name) do
      :undefined ->
        via_tuple = {:via, @registry, name}
        Supervisor.start_child(generator, [channel, [name: via_tuple]])
      pid ->
        {:ok, {:already_connected, pid}}
    end
  end

  @doc """
  Stops a distributor using the `channel` information.
  """
  def stop_distributor(%Channel{} = channel) do
    name = {@distributor, channel}
    case @registry.whereis_name(name) do
      :undefined ->
        :ok
      pid ->
        @distributor.stop(pid)
    end
  end

  #############################################################################
  # Supervisor callback.

  @doc false
  def init(_) do
    import Supervisor.Spec

    children = [
      supervisor(@distributor, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
