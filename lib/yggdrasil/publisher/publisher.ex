defmodule Yggdrasil.Publisher do
  @moduledoc """
  Publisher pool of processes.
  """
  use Supervisor

  alias Yggdrasil.Channel

  @registry Application.get_env(:yggdrasil, :registry, ExReg)

  #############################################################################
  # Client API.

  @doc """
  Starts a pool of publisher adapters using the information of a `channel`.
  Additionally can receive `Supervisor` `options`.
  """
  def start_link(%Channel{} = channel, options \\ []) do
    channel = %Channel{channel | name: nil}
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

  @doc """
  Publishes `message` in a `channel`.
  """
  def publish(%Channel{adapter: adapter} = channel, message) do
    base = %Channel{channel | name: nil}
    pool_name = {:via, @registry, {Poolboy, base}}
    :poolboy.transaction(pool_name, fn worker ->
      adapter.publish(worker, channel, message)
    end)
  end

  #############################################################################
  # Supervisor callback.

  @doc false
  def init(%Channel{adapter: adapter, namespace: namespace} = channel) do
    import Supervisor.Spec

    via_tuple = {:via, @registry, {Poolboy, channel}}
    poolargs = [
      name: via_tuple,
      worker_module: adapter,
    ] ++ publisher_options(channel)

    children = [
      :poolboy.child_spec(via_tuple, poolargs, namespace)
    ]
    supervise(children, strategy: :one_for_one)
  end

  #############################################################################
  # Helpers.

  @doc false
  def publisher_options(%Channel{namespace: nil}) do
    default = [size: 5, max_overflow: 10]
    Application.get_env(:yggdrasil, :publisher_options, default)
  end
  def publisher_options(%Channel{namespace: namespace}) do
    default = [publisher_options: [size: 5, max_overflow: 10]]
    options = Application.get_env(:yggdrasil, namespace, default)
    Keyword.get(options, :publisher_options, [size: 5, max_overflow: 10])
  end
end
