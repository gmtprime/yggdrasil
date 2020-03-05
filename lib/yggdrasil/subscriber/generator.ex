defmodule Yggdrasil.Subscriber.Generator do
  @moduledoc """
  Supervisor to generate distributors on demand.
  """
  use DynamicSupervisor

  alias Yggdrasil.Channel
  alias Yggdrasil.Subscriber.Distributor
  alias Yggdrasil.Subscriber.Manager

  ############
  # Client API

  @doc """
  Starts a distributor generator with `Supervisor` `options`.
  """
  @spec start_link() :: Supervisor.on_start()
  @spec start_link([DynamicSupervisor.option() | DynamicSupervisor.init_option()]) ::
          Supervisor.on_start()
  def start_link(options \\ []) do
    DynamicSupervisor.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops a distributor `generator`.
  """
  @spec stop(Supervisor.supervisor()) :: :ok
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
  @spec subscribe(Channel.t(), nil | pid(), keyword()) :: :ok | {:error, term()}
  def subscribe(channel, pid \\ nil, options \\ [])

  def subscribe(%Channel{} = channel, nil, options) do
    subscribe(channel, self(), options)
  end

  def subscribe(%Channel{} = channel, pid, options) when is_pid(pid) do
    name = {Distributor, channel}

    case ExReg.whereis_name(name) do
      :undefined ->
        generator = Keyword.get(options, :name, __MODULE__)
        start_distributor(generator, channel, pid)

      _distributor ->
        do_subscribe(channel, pid)
    end
  end

  @doc false
  @spec start_distributor(Supervisor.supervisor(), Channel.t(), pid()) ::
          :ok | {:error, term()}
  def start_distributor(generator, %Channel{} = channel, pid) do
    via_tuple = ExReg.local({Distributor, channel})

    spec = %{
      id: via_tuple,
      start: {Distributor, :start_link, [channel, pid, [name: via_tuple]]},
      restart: :transient
    }

    case DynamicSupervisor.start_child(generator, spec) do
      {:ok, _} ->
        :ok

      {:error, {:already_started, _}} ->
        do_subscribe(channel, pid)

      _ ->
        {:error, "Cannot subscribe to #{inspect(channel)}"}
    end
  end

  @doc false
  @spec do_subscribe(Channel.t(), pid()) :: :ok | {:error, term()}
  def do_subscribe(%Channel{} = channel, pid) do
    Manager.add(channel, pid)
  end

  @doc """
  Makes a `pid` unsubscribe from a `channel`.
  """
  @spec unsubscribe(Channel.t()) :: :ok | {:error, term()}
  @spec unsubscribe(Channel.t(), nil | pid()) :: :ok | {:error, term()}
  def unsubscribe(channel, pid \\ nil)

  def unsubscribe(%Channel{} = channel, nil) do
    unsubscribe(channel, self())
  end

  def unsubscribe(%Channel{} = channel, pid) when is_pid(pid) do
    Manager.remove(channel, pid)
  end

  @doc false
  @spec stop_distributor(Channel.t()) :: :ok
  def stop_distributor(%Channel{} = channel) do
    name = {Distributor, channel}

    case ExReg.whereis_name(name) do
      :undefined ->
        :ok

      pid ->
        spawn(fn -> Distributor.stop(pid) end)
    end
  end

  #####################
  # Supervisor callback

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
