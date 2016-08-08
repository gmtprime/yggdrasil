defmodule Yggdrasil.Publisher.Generator do
  @moduledoc """
  Supervisor to generate publisher supervisors on demand.
  """
  use Supervisor
  import Supervisor.Spec

  alias Yggdrasil.Channel

  @supervisor Yggdrasil.Publisher.Supervisor
  @registry ExReg

  ###################
  # Client functions.

  @doc """
  Starts a generator supervisor with `Supervisor` `options`.
  """
  def start_link(options \\ []) do
    Supervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a `generator` with a `reason`. By default is  `reason` is `:normal`.
  """
  def stop(generator, reason \\ :normal) do
    for child <- Supervisor.which_children(generator) do
      {_, pid, _, _} = child
      apply(@supervisor, :stop, [pid, reason])
    end
    Supervisor.stop(generator, reason)
  end

  @doc """
  Starts a publisher using a `generator` supervisor and a `channel`.
  """
  def start_publisher(generator, %Channel{} = channel) do
    registry = get_registry()
    name = gen_supervisor_name(channel)
    case apply(registry, :whereis_name, [name]) do
      :undefined ->
        via_tuple = {:via, registry, name}
        Supervisor.start_child(generator, [channel, [name: via_tuple]])
      pid ->
        {:ok, pid}
    end
  end

  @doc """
  Stops a publisher using a `channel`. By default the `reason` to stop the 
  publisher is `:normal`.
  """
  def stop_publisher(%Channel{} = channel, reason \\ :normal) do
    name = gen_supervisor_name(channel)
    apply(@supervisor, :stop, [name, reason])
  end

  @doc false
  def get_registry do
    Application.get_env(:yggdrasil, :registry, @registry)
  end

  ###################
  # Helper functions.

  ##
  # Generates the publisher supervisor name using the `channel` information.
  defp gen_supervisor_name(%Channel{channel: channel, decoder: decoder}) do
    registry = get_registry()
    {:via, registry, {@supervisor, channel, decoder}}
  end

  ######################
  # Supervisor callback.

  @doc false
  def init(_) do
    children = [
      supervisor(@supervisor, [], restart: :transient)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
