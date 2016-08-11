defmodule Yggdrasil.Publisher.Supervisor do
  @moduledoc """
  Supervisor for `Yggdrasil.Publisher`s and `Yggdrasil.Adapter`s.
  """
  use Supervisor
  import Supervisor.Spec

  alias Yggdrasil.Channel
  alias Yggdrasil.Publisher.Generator

  @publisher Yggdrasil.Publisher
  @adapter Yggdrasil.Adapter

  ###################
  # Client functions.

  @doc """
  Starts the supervisor and its children using the `channel` as part
  of the identificator for the supervision tree. Additionaly you can pass
  a list of `Supervisor` `options`.
  """
  def start_link(%Channel{} = channel, options \\ []) do
    Supervisor.start_link(__MODULE__, channel, options)
  end

  @doc """
  Stops the `supervisor`.
  """
  def stop(supervisor) do
    if Process.alive?(supervisor), do: stop(supervisor, :normal), else: :ok
  end

  @doc """
  Stops the `supervisor` and using its `name` or its PID and a `reason` for
  termination.
  """
  def stop(supervisor, reason) when is_pid(supervisor) do
    try do
      for {module, child, _, _} <- Supervisor.which_children(supervisor) do
        apply(module, :stop, [child, reason])
      end
      Supervisor.stop(supervisor, reason)
    rescue
      _ -> :ok
    end
  end
  def stop(name, reason) do
    registry = Generator.get_registry()
    case registry.whereis_name(name) do
      :undefined -> :ok
      pid -> stop(pid, reason)
    end
  end

  ##########
  # Helpers.

  ##
  # Creates a via tuple using a process name registry and a `name` for the
  # process.
  defp via_tuple(name) do
    registry = Generator.get_registry()
    {:via, registry, name}
  end

  ##
  # Generates the publisher name from a `channel`.
  defp gen_publisher_name(%Channel{} = channel) do
    gen_name(@publisher, channel)
  end

  ##
  # Generates the adapter name from a `channel`.
  @doc false
  def gen_adapter_name(%Channel{} = channel) do
    gen_name(@adapter, channel)
  end

  ##
  # Generates the name using a `prefix` (publisher or adapter) and a `channel`
  # structure.
  defp gen_name(prefix, %Channel{channel: channel, decoder: decoder}) do
    {prefix, channel, decoder}
  end

  ######################
  # Supervisor callback.

  @doc false
  def init(%Channel{decoder: decoder} = channel) do
    adapter = channel |> gen_adapter_name() |> via_tuple()
    publisher = channel |> gen_publisher_name() |> via_tuple()
    adapter_module = decoder.get_adapter()

    children = [
      worker(@publisher,
             [channel, [name: publisher]], restart: :transient),
      worker(adapter_module,
             [channel, publisher, [name: adapter]], restart: :transient)
    ]
    supervise(children, strategy: :rest_for_one)
  end
end
