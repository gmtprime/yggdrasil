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
  @spec start_link() :: Supervisor.on_start()
  @spec start_link([
          DynamicSupervisor.option() | DynamicSupervisor.init_option()
        ]) ::
          Supervisor.on_start()
  def start_link(options \\ [])

  def start_link(options) do
    DynamicSupervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a publisher `generator`.
  """
  @spec stop(Supervisor.supervisor()) :: :ok
  def stop(generator)

  def stop(generator) do
    generator
    |> Supervisor.which_children()
    |> Stream.map(&elem(&1, 0))
    |> Enum.each(&Supervisor.terminate_child(generator, &1))

    Supervisor.stop(generator)
  end

  @doc """
  Starts a publisher using the `generator` and the `channel` to identify the
  connection.
  """
  @spec start_publisher(Supervisor.supervisor(), Channel.t()) ::
          DynamicSupervisor.on_start_child()
  def start_publisher(generator, channel)

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
