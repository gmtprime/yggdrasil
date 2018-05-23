defmodule Yggdrasil.Distributor do
  @moduledoc """
  Supervisor for `Yggdrasil.Distributor.Manager`,
  `Yggdrasil.Distributor.Adapter` and `Yggdrasil.Distributor.Publisher`.
  """
  use Supervisor

  alias Yggdrasil.Channel
  alias Yggdrasil.Settings
  alias Yggdrasil.Distributor.Manager
  alias Yggdrasil.Distributor.Publisher

  @registry Settings.registry()

  #############################################################################
  # Client API.

  @doc """
  Starts the supervisor and its children using the `channel` as part of the
  identificator for the supervision tree. It also receives the `pid` of
  the first subscriber. Additionally it can receive `Supervisor` `options`.
  """
  def start_link(%Channel{} = channel, pid, options \\ []) do
    Supervisor.start_link(__MODULE__, [channel, pid], options)
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
  def init([%Channel{adapter: adapter_module} = channel, pid]) do
    import Supervisor.Spec

    manager_name = {:via, @registry, {Manager, channel}}
    publisher_name = {:via, @registry, {Publisher, channel}}
    adapter_name = {:via, @registry, {adapter_module, channel}}

    children = [
      worker(
        Manager,
        [channel, pid, [name: manager_name]],
        restart: :transient
      ),
      worker(
        Publisher,
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
