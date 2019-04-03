defmodule Yggdrasil.Publisher.Generator do
  @moduledoc """
  Generator of publisher pools.
  """
  use DynamicSupervisor

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher

  ############
  # Client API

  @doc """
  Starts a publisher generator with `Supervisor` `options`.
  """
  def start_link(options \\ []) do
    DynamicSupervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a publisher `generator`.
  """
  def stop(generator) do
    for {_, pid, _, _} <- Supervisor.which_children(generator) do
      try do
        Publisher.stop(pid)
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
    name = {Publisher, channel}

    case ExReg.whereis_name(name) do
      :undefined ->
        via_tuple = ExReg.local(name)

        spec = %{
          id: via_tuple,
          start: {Publisher, :start_link, [channel, [name: via_tuple]]},
          restart: :transient
        }

        case DynamicSupervisor.start_child(generator, spec) do
          {:error, {:already_started, pid}} ->
            {:ok, {:already_connected, pid}}

          other ->
            other
        end

      pid ->
        {:ok, {:already_connected, pid}}
    end
  end

  #####################
  # Supervisor callback

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
