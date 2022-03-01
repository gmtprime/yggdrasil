defmodule Yggdrasil.Subscriber.Distributor do
  @moduledoc """
  Supervisor for `Yggdrasil.Subscriber.Manager`,
  `Yggdrasil.Subscriber.Adapter` and `Yggdrasil.Subscriber.Publisher`.
  """
  use Supervisor

  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Adapter
  alias Yggdrasil.Subscriber.Manager
  alias Yggdrasil.Subscriber.Publisher

  ############
  # Client API

  @doc """
  Starts the supervisor and its children using the `channel` as part of the
  identificator for the supervision tree. It also receives the `pid` of
  the first subscriber. Additionally it can receive `Supervisor` `options`.
  """
  @spec start_link(Channel.t(), pid(), [
          Supervisor.option() | Supervisor.init_option()
        ]) ::
          Supervisor.on_start()
  def start_link(channel, pid, options \\ [])

  def start_link(%Channel{} = channel, pid, options) do
    Supervisor.start_link(__MODULE__, [channel, pid], options)
  end

  @doc """
  Stops the `supervisor`.
  """
  @spec stop(Supervisor.supervisor()) :: :ok
  def stop(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Stream.map(&elem(&1, 0))
    |> Enum.each(&Supervisor.terminate_child(supervisor, &1))

    Supervisor.stop(supervisor)
  end

  #####################
  # Supervisor callback

  @impl true
  def init([%Channel{} = channel, pid]) do
    Process.flag(:trap_exit, true)
    manager_name = ExReg.local({Manager, channel})
    publisher_name = ExReg.local({Publisher, channel})
    adapter_name = ExReg.local({Adapter, channel})

    children = [
      %{
        id: Manager,
        start: {Manager, :start_link, [channel, pid, [name: manager_name]]},
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
      }
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
