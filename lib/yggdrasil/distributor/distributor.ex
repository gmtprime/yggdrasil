defmodule Yggdrasil.Distributor do
  @moduledoc """
  Supervisor for `Yggdrasil.Distributor.Adapter` and
  `Yggdrasil.Distributor.Publisher`.
  """
  use Supervisor

  alias Yggdrasil.Channel

  @publisher Yggdrasil.Distributor.Publisher
  @registry Application.get_env(:yggdrasil, :registry, ExReg)

  #############################################################################
  # Client API.

  @doc """
  Starts the supervisor and its children using the `channel` as part of the
  identificator for the supervision tree. Additionally it can receive
  `Supervisor` `options`.
  """
  def start_link(%Channel{} = channel, options \\ []) do
    Supervisor.start_link(__MODULE__, channel, options)
  end

  @doc """
  Stops the `supervisor`.
  """
  def stop(supervisor) do
    for {module, child, _, _} <- Supervisor.which_children(supervisor) do
      try do
        apply(module, :stop, [child])
      catch
        _, _ -> :ok
      end
    end
    Supervisor.stop(supervisor)
  end

  #############################################################################
  # Supervisor callback.

  @doc false
  def init(%Channel{adapter: adapter_module} = channel) do
    import Supervisor.Spec

    adapter_name = {:via, @registry, {adapter_module, channel}}
    publisher_name = {:via, @registry, {@publisher, channel}}

    children = [
      worker(
        @publisher,
        [channel, [name: publisher_name]],
        restart: :transient
      ),
      worker(
        adapter_module,
        [channel, publisher_name, [name: adapter_name]],
        restart: :transient
      )
    ]
    supervise(children, strategy: :rest_for_one)
  end
end
