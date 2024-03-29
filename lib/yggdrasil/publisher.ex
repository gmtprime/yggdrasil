defmodule Yggdrasil.Publisher do
  @moduledoc """
  Publisher pool of processes.
  """
  use Supervisor

  alias Yggdrasil.Channel
  alias Yggdrasil.Config
  alias Yggdrasil.Publisher.Adapter

  ############
  # Client API

  @doc """
  Starts a pool of publisher adapters using the information of a `channel`.
  Additionally can receive `Supervisor` `options`.
  """
  @spec start_link(Channel.t()) :: Supervisor.on_start()
  @spec start_link(Channel.t(), [Supervisor.option() | Supervisor.init_option()]) ::
          Supervisor.on_start()
  def start_link(channel, options \\ [])

  def start_link(%Channel{} = channel, options) do
    channel = %Channel{channel | name: nil}
    Supervisor.start_link(__MODULE__, channel, options)
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

  @doc """
  Publishes `message` in a `channel` with some optional `options`.
  """
  @spec publish(Channel.t(), term()) :: :ok | {:error, term()}
  @spec publish(Channel.t(), term(), keyword()) :: :ok | {:error, term()}
  def publish(channel, message, options \\ [])

  def publish(%Channel{} = channel, message, options) do
    base = %Channel{channel | name: nil}
    pool_name = ExReg.local({Poolboy, base})

    :poolboy.transaction(pool_name, fn worker ->
      Adapter.publish(worker, channel, message, options)
    end)
  end

  #####################
  # Supervisor callback

  @impl true
  def init(%Channel{namespace: namespace} = channel) do
    Process.flag(:trap_exit, true)
    via_tuple = ExReg.local({Poolboy, channel})

    poolargs =
      namespace
      |> Config.publisher_options!()
      |> Keyword.put(:name, via_tuple)
      |> Keyword.put(:worker_module, Adapter)

    children = [
      %{
        id: via_tuple,
        start: {:poolboy, :start_link, [poolargs, channel]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
