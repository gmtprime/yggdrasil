defmodule Yggdrasil.Subscriber.Generator do
  @moduledoc """
  Supervisor to generate distributors on demand.
  """
  use DynamicSupervisor

  alias Yggdrasil.Channel
  alias Yggdrasil.Settings
  alias Yggdrasil.Subscriber.Distributor
  alias Yggdrasil.Subscriber.Manager

  @registry Settings.yggdrasil_process_registry()

  ############
  # Client API

  @doc """
  Starts a distributor generator with `Supervisor` `options`.
  """
  @spec start_link() :: Supervisor.on_start()
  @spec start_link(Supervisor.options()) :: Supervisor.on_start()
  def start_link(options \\ []) do
    DynamicSupervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a distributor `generator`.
  """
  @spec stop(Supervisor.name()) :: :ok
  def stop(generator) do
    for {_, pid, _, _} <- Supervisor.which_children(generator) do
      try do
        Distributor.stop(pid)
      catch
        _, _ -> :ok
      end
    end
    Supervisor.stop(generator)
  end

  @doc """
  Makes a `pid` subscribe to a `channel`.
  """
  @spec subscribe(Channel.t()) :: :ok | {:error, term()}
  @spec subscribe(Channel.t(), pid()) :: :ok | {:error, term()}
  @spec subscribe(Channel.t(), pid(), Keyword.t()) :: :ok | {:error, term()}
  def subscribe(channel, pid \\ nil, options \\ [])

  def subscribe(%Channel{} = channel, nil, options) do
    subscribe(channel, self(), options)
  end
  def subscribe(%Channel{} = channel, pid, options) when is_pid(pid) do
    name = {Distributor, channel}
    case @registry.whereis_name(name) do
      :undefined ->
        generator = Keyword.get(options, :name, __MODULE__)
        start_distributor(generator, channel, pid)
      _distributor ->
        do_subscribe(channel, pid)
    end
  end

  @doc false
  @spec start_distributor(Supervisor.name(), Channel.t(), pid())
    :: :ok | {:error, term()}
  def start_distributor(generator, %Channel{} = channel, pid) do
    name = {Distributor, channel}
    via_tuple = {:via, @registry, name}
    spec = %{
      id: via_tuple,
      start: {Distributor, :start_link, [channel, pid, [name: via_tuple]]},
      restart: :transient
    }
    with {:ok, _} <- DynamicSupervisor.start_child(generator, spec) do
      :ok
    else
      _ ->
        {:error, "Cannot subscribe to #{inspect channel}"}
    end
  end

  @doc false
  @spec do_subscribe(Channel.t(), pid()) :: :ok | {:error, term()}
  def do_subscribe(%Channel{} = channel, pid) do
    try do
      Manager.add(channel, pid)
    catch
      :exit, {:timeout, _} ->
        {:error, "Manager is not available for subscriptions"}
    end
  end

  @doc """
  Makes a `pid` unsubscribe from a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok
  @spec unsubscribe(Channel.t(), pid()) :: :ok
  def unsubscribe(channel, pid \\ nil)

  def unsubscribe(%Channel{} = channel, nil) do
    unsubscribe(channel, self())
  end
  def unsubscribe(%Channel{} = channel, pid) when is_pid(pid) do
    try do
      Manager.remove(channel, pid)
    catch
      :exit, {:timeout, _} ->
        {:error, "Manager not available for unsubscriptions"}
    end
  end

  @doc false
  @spec stop_distributor(Channel.t()) :: :ok
  def stop_distributor(%Channel{} = channel) do
    name = {Distributor, channel}
    case @registry.whereis_name(name) do
      :undefined ->
        :ok
      pid ->
        spawn fn -> Distributor.stop(pid) end
    end
  end

  #####################
  # Supervisor callback

  @doc false
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
