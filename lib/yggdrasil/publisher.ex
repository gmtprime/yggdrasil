defmodule Yggdrasil.Publisher do
  @moduledoc """
  Publisher pool of processes.
  """
  use Supervisor

  alias Yggdrasil.Channel
  alias Yggdrasil.Settings
  alias Yggdrasil.Publisher.Adapter

  @registry Settings.yggdrasil_process_registry()

  ############
  # Client API

  @doc """
  Starts a pool of publisher adapters using the information of a `channel`.
  Additionally can receive `Supervisor` `options`.
  """
  @spec start_link(Channel.t()) :: Supervisor.on_start()
  @spec start_link(Channel.t(), Supervisor.options()) :: Supervisor.on_start()
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
    for {module, child, _, _} <- Supervisor.which_children(supervisor) do
      try do
        apply(module, :stop, [child])
      catch
        _, _ -> :ok
      end
    end
    Supervisor.stop(supervisor)
  end

  @doc """
  Publishes `message` in a `channel` with some optional `options`.
  """
  @spec publish(Channel.t(), term()) :: :ok | {:error, term()}
  @spec publish(Channel.t(), term(), Keyword.t()) :: :ok | {:error, term()}
  def publish(channel, message, options \\ [])

  def publish(%Channel{} = channel, message, options) do
    base = %Channel{channel | name: nil}
    pool_name = {:via, @registry, {Poolboy, base}}
    :poolboy.transaction(pool_name, fn worker ->
      Adapter.publish(worker, channel, message, options)
    end)
  end

  #####################
  # Supervisor callback

  @impl true
  def init(%Channel{} = channel) do
    via_tuple = {:via, @registry, {Poolboy, channel}}

    poolargs =
      channel
      |> publisher_options()
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

  #########
  # Helpers

  @doc false
  def publisher_options(%Channel{namespace: nil}) do
    Settings.yggdrasil_publisher_options()
  end
  def publisher_options(%Channel{namespace: namespace}) do
    name = Settings.gen_env_name(namespace, :publisher_options)
    Skogsra.get_app_env(:yggdrasil, :publisher_options,
      domain: namespace,
      default: Settings.yggdrasil_publisher_options(),
      name: name
    )
  end
end
