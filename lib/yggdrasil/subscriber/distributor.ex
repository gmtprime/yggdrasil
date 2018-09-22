defmodule Yggdrasil.Subscriber.Distributor do
  @moduledoc """
  Supervisor for `Yggdrasil.Subscriber.Manager`,
  `Yggdrasil.Subscriber.Adapter` and `Yggdrasil.Subscriber.Publisher`.
  """
  use Supervisor

  alias Yggdrasil.Channel
  alias Yggdrasil.Settings
  alias Yggdrasil.Subscriber.Adapter
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Subscriber.Publisher

  @registry Settings.yggdrasil_process_registry()

  #############################################################################
  # Client API.

  @doc """
  Starts the supervisor and its children using the `channel` as part of the
  identificator for the supervision tree. It also receives the `pid` of
  the first subscriber. Additionally it can receive `Supervisor` `options`.
  """
  @spec start_link(
    Channel.t(),
    pid(),
    Supervisor.options()
  ) :: Supervisor.on_start()
  def start_link(channel, pid, options \\ [])

  def start_link(%Channel{} = channel, pid, options) do
    Supervisor.start_link(__MODULE__, [channel, pid], options)
  end

  @doc """
  Stops the `supervisor`.
  """
  @spec stop(Supervisor.name()) :: :ok
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

  @impl true
  def init([%Channel{} = channel, pid]) do
    manager_name = {:via, @registry, {Manager, channel}}
    publisher_name = {:via, @registry, {Publisher, channel}}
    adapter_name = {:via, @registry, {Adapter, channel}}

    children = [
      %{
        id: Manager,
        start: {Manager, :start_link, [channel, [name: manager_name]]},
        restart: :transient
      },
      %{
        id: Task,
        start: {Task, :start_link, [fn -> Manager.add(channel, pid) end]},
        restart: :transient
      },
      %{
        id: Publisher,
        start: {Publisher, :start_link, [channel, [name: publisher_name]]},
        restart: :transient
      },
      %{
        id: Adapter,
        start: {Adapter, :start_link, [channel, [name: adapter_name]]},
        restart: :transient
      },
    ]
    Supervisor.init(children, strategy: :rest_for_one)
  end
end
