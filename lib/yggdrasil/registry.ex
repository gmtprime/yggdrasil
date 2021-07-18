defmodule Yggdrasil.Registry do
  @moduledoc """
  Yggdrasil `Registry` for adapters, transformers and backends aliases.
  """
  use Supervisor

  alias Yggdrasil.Channel

  @typedoc """
  Registry alias.
  """
  @type name :: atom()

  @typedoc """
  Registry type.
  """
  @type type :: :transformer | :backend | :subscriber | :publisher | :adapter

  ############
  # Public API

  @spec start_link([Supervisor.option() | Supervisor.init_option()]) ::
          Supervisor.on_start()
  def start_link(_) do
    Supervisor.start_link(__MODULE__, nil, name: Yggdrasil.Registry.Supervisor)
  end

  @doc """
  Registers a transformer.
  """
  @spec register_transformer(name(), module()) :: :ok
  def register_transformer(name, module) do
    register(:transformer, name, module)
  end

  @doc """
  Registers a backend.
  """
  @spec register_backend(name(), module()) :: :ok
  def register_backend(name, module) do
    register(:backend, name, module)
  end

  @doc """
  Registers an adapter.
  """
  @spec register_adapter(name(), module()) :: :ok
  def register_adapter(name, module) do
    with {:ok, subscriber} <- module.get_subscriber_module(),
         :ok <- register(:subscriber, name, subscriber),
         :ok <- global_register(subscriber),
         {:ok, publisher} <- module.get_publisher_module(),
         :ok <- register(:publisher, name, publisher),
         :ok <- global_register(publisher),
         :ok <- register(:adapter, name, module),
         :ok <- global_register(module) do
      global_register(name)
    end
  end

  @doc """
  Gets adapter node by `name`.
  """
  @spec get_adapter_node(name() | module()) ::
          {:ok, node()}
          | {:error, binary()}
  def get_adapter_node(name) do
    group = {__MODULE__, name}

    with [] <- :pg.get_local_members(__MODULE__, group),
         [] <- :pg.get_members(__MODULE__, group) do
      {:error, "Yggdrasil #{name} not registered in any node"}
    else
      [pid | _] ->
        {:ok, node(pid)}
    end
  end

  @doc """
  Gets full channel given a `channel`.
  """
  @spec get_full_channel(Channel.t()) ::
          {:ok, Channel.t()}
          | {:error, binary()}
  def get_full_channel(%Channel{adapter: name} = channel) do
    node = node()

    case get_adapter_node(name) do
      {:ok, ^node} ->
        get_local_channel(channel)

      {:ok, _} ->
        get_bridge_channel(channel)

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Gets transformer module.
  """
  @spec get_transformer_module(name() | module()) ::
          {:ok, module()}
          | {:error, binary()}
  def get_transformer_module(name) do
    get_module(:transformer, name)
  end

  @doc """
  Gets backend module.
  """
  @spec get_backend_module(name() | module()) ::
          {:ok, module()}
          | {:error, binary()}
  def get_backend_module(name) do
    get_module(:backend, name)
  end

  @doc """
  Gets subscriber module.
  """
  @spec get_subscriber_module(name() | module()) ::
          {:ok, module()}
          | {:error, binary()}
  def get_subscriber_module(name) do
    get_module(:subscriber, name)
  end

  @doc """
  Gets publisher module.
  """
  @spec get_publisher_module(name() | module()) ::
          {:ok, module()}
          | {:error, binary()}
  def get_publisher_module(name) do
    get_module(:publisher, name)
  end

  @doc """
  Gets adapter module.
  """
  @spec get_adapter_module(name() | module()) ::
          {:ok, module()}
          | {:error, binary()}
  def get_adapter_module(name) do
    get_module(:adapter, name)
  end

  ######################
  # Supervisor callbacks

  @impl Supervisor
  def init(_) do
    children = [%{id: __MODULE__, start: {:pg, :start_link, [__MODULE__]}}]

    Supervisor.init(children, strategy: :one_for_one)
  end

  ############
  # Public API

  #########
  # Helpers

  # Registers a new `type` of `module` with its `name` or alias.
  @spec register(type(), name(), module()) :: :ok
  defp register(type, name, module) do
    :persistent_term.put({__MODULE__, type, name}, module)
    :persistent_term.put({__MODULE__, type, module}, module)

    :ok
  end

  @spec global_register(name() | module()) :: :ok
  defp global_register(module) do
    group = {__MODULE__, module}
    pid = Process.whereis(Yggdrasil.Registry.Supervisor)

    with [_ | _] = pids <- :pg.get_local_members(__MODULE__, group),
         true <- pid in pids do
      :ok
    else
      _ ->
        :pg.join(__MODULE__, group, pid)
    end
  end

  # Gets bridge channel.
  @spec get_bridge_channel(Channel.t()) ::
          {:ok, Channel.t()}
          | {:error, binary()}
  defp get_bridge_channel(%Channel{} = channel) do
    get_local_channel(%Channel{name: channel, adapter: :bridge})
  end

  # Gets local channel.
  @spec get_local_channel(Channel.t()) ::
          {:ok, Channel.t()}
          | {:error, binary()}
  defp get_local_channel(%Channel{adapter: adapter} = channel) do
    with {:ok, adapter} <- get_adapter_module(adapter),
         transformer = channel.transformer || adapter.get_transformer(),
         {:ok, _} <- get_transformer_module(transformer),
         backend = channel.backend || adapter.get_backend(),
         {:ok, _} <- get_backend_module(backend) do
      channel = %Channel{
        channel
        | transformer: transformer,
          backend: backend
      }

      {:ok, channel}
    end
  end

  # Gets the cached module.
  @spec get_module(type(), name() | module()) ::
          {:ok, module()}
          | {:error, binary()}
  defp get_module(type, name) do
    key = {__MODULE__, type, name}

    case :persistent_term.get(key, nil) do
      nil ->
        {:error, "Yggdrasil #{type}: #{name} not loaded"}

      module ->
        {:ok, module}
    end
  end
end
