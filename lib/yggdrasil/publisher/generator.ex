defmodule Yggdrasil.Publisher.Generator do
  @moduledoc """
  Generator of publisher pools.
  """
  use Supervisor

  alias Yggdrasil.Channel
  alias Yggdrasil.Settings

  @publisher Yggdrasil.Publisher
  @registry Settings.registry()

  ############
  # Client API

  @doc """
  Starts a publisher generator with `Supervisor` `options`.
  """
  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a publisher `generator`.
  """
  def stop(generator) do
    for {_, pid, _, _} <- Supervisor.which_children(generator) do
      try do
        @publisher.stop(pid)
      catch
        _, _ -> :ok
      end
    end
    Supervisor.stop(generator)
  end

  @doc """
  Starts a publisher using the `generator` and the `channel` to identify the
  connection.
  """
  def start_publisher(generator, %Channel{} = channel) do
    channel = %Channel{channel | name: nil}
    name = {@publisher, channel}
    case @registry.whereis_name(name) do
      :undefined ->
        via_tuple = {:via, @registry, name}
        case Supervisor.start_child(generator, [channel, [name: via_tuple]]) do
          {:error, {:already_started, pid}} ->
            {:ok, {:already_connected, pid}}
          {:error, _} = error -> error
          ok -> ok
        end
      pid ->
        {:ok, {:already_connected, pid}}
    end
  end

  #####################
  # Supervisor callback

  @doc false
  def init(_) do
    import Supervisor.Spec

    children = [
      supervisor(@publisher, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
