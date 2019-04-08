defmodule Yggdrasil.Registry do
  @moduledoc """
  Yggdrasil `Registry` for adapters, transformers and backends aliases.
  """
  use Agent

  alias Yggdrasil.Channel
  alias Yggdrasil.Settings

  @module_registry Settings.module_registry!()

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

  @doc """
  Starts a registry with some optional `options`.
  """
  @spec start_link() :: Agent.on_start()
  @spec start_link(Agent.options()) :: Agent.on_start()
  def start_link(options \\ []) do
    opts = [
      :set,
      :named_table,
      :public,
      write_concurrency: true,
      read_concurrency: true
    ]

    start_link(@module_registry, opts, options)
  end

  @doc """
  Stops a `registry` with optional `reason` and `timeout`.
  """
  @spec stop(pid() | GenServer.name()) :: :ok
  @spec stop(pid() | GenServer.name(), term()) :: :ok
  @spec stop(pid() | GenServer.name(), term(), :infinity | pos_integer()) :: :ok
  defdelegate stop(agent, reason \\ :normal, timeout \\ :infinity), to: Agent

  @doc """
  Registers a transformer.

  Creates the following entries in the #{@module_registry} `:ets` table:

  ```
  - {:transformer, name()}   => module()
  - {:transformer, module()} => module()
  ```
  """
  @spec register_transformer(name(), module()) :: :ok
  def register_transformer(name, module) do
    register_transformer(@module_registry, name, module)
  end

  @doc """
  Registers a backend.

  Creates the following entries in the #{@module_registry} `:ets` table:

  ```
  - {:backend, name()}   => module()
  - {:backend, module()} => module()
  ```
  """
  @spec register_backend(name(), module()) :: :ok
  def register_backend(name, module) do
    register_backend(@module_registry, name, module)
  end

  @doc """
  Registers an adapter.

  Creates the following entries in the #{@module_registry} `:ets` table:

  ```
  - {:adapter, name()}      => module()
  - {:adapter, module()}    => module()

  - {:subscriber, name()}   => module()
  - {:subscriber, module()} => module()

  - {:publisher, name()}    => module()
  - {:publisher, module()}  => module()
  ```

  And also creates the following `:pg2` groups:

  ```
  - {:"$yggdrasil_registry", name()}              => pid()
  - {:"$yggdrasil_registry", module()}            => pid()
  - {:"$yggdrasil_registry", subscriber_module()} => pid()
  - {:"$yggdrasil_registry", publisher_module()}  => pid()
  ```
  """
  @spec register_adapter(name(), module()) :: :ok
  def register_adapter(name, module) do
    register_adapter(@module_registry, name, module)
  end

  @doc """
  Gets adapter node by `name`.
  """
  @spec get_adapter_node(atom()) :: {:ok, node()} | {:error, term()}
  def get_adapter_node(name) do
    get_adapter_node(@module_registry, name)
  end

  @doc """
  Gets full channel.
  """
  @spec get_full_channel(Channel.t()) ::
          {:ok, Channel.t()} | {:error, term()}
  def get_full_channel(%Channel{} = channel) do
    get_full_channel(@module_registry, channel)
  end

  @doc """
  Gets transformer module.
  """
  @spec get_transformer_module(atom()) :: {:ok, module()} | {:error, term()}
  def get_transformer_module(name) do
    get_transformer_module(@module_registry, name)
  end

  @doc """
  Gets backend module.
  """
  @spec get_backend_module(atom()) :: {:ok, module()} | {:error, term()}
  def get_backend_module(name) do
    get_backend_module(@module_registry, name)
  end

  @doc """
  Gets subscriber module.
  """
  @spec get_subscriber_module(atom()) :: {:ok, module()} | {:error, term()}
  def get_subscriber_module(name) do
    get_subscriber_module(@module_registry, name)
  end

  @doc """
  Gets publisher module.
  """
  @spec get_publisher_module(atom()) :: {:ok, module()} | {:error, term()}
  def get_publisher_module(name) do
    get_publisher_module(@module_registry, name)
  end

  @doc """
  Gets adapter module.
  """
  @spec get_adapter_module(atom()) :: {:ok, module()} | {:error, term()}
  def get_adapter_module(name) do
    get_adapter_module(@module_registry, name)
  end

  ###############
  # Agent helpers

  # Starts a Registry.
  @doc false
  @spec start_link(:ets.tab(), list(), Agent.options()) :: Agent.on_start()
  def start_link(table, table_opts, options) do
    Agent.start_link(fn -> :ets.new(table, table_opts) end, options)
  end

  # Gets table.
  @doc false
  @spec get(pid() | Agent.name()) :: :ets.tab()
  def get(registry) do
    Agent.get(registry, & &1)
  end

  ######################
  # Registration helpers

  # Registers a transformer.
  @doc false
  @spec register_transformer(:ets.tab(), name(), module()) :: :ok
  def register_transformer(table, name, module) do
    register(table, :transformer, name, module)
  end

  # Registers a backend.
  @doc false
  @spec register_backend(:ets.tab(), name(), module()) :: :ok
  def register_backend(table, name, module) do
    register(table, :backend, name, module)
  end

  # Registers an adapter.
  @doc false
  @spec register_adapter(:ets.tab(), name(), module()) ::
          :ok | {:error, term()}
  def register_adapter(table, name, module) do
    with {:ok, subscriber} <- module.get_subscriber_module(),
         {:ok, publisher} <- module.get_publisher_module(),
         :ok <- register_subscriber(table, name, subscriber),
         :ok <- register_publisher(table, name, publisher) do
      register_global(table, name)
      register_global(table, module)
      register_global(table, subscriber)
      register_global(table, publisher)
      register(table, :adapter, name, module)
    end
  end

  # Registers a subscriber.
  @doc false
  @spec register_subscriber(:ets.tab(), name(), module()) :: :ok
  def register_subscriber(table, name, module) do
    register(table, :subscriber, name, module)
  end

  # Registers a publisher.
  @doc false
  @spec register_publisher(:ets.tab(), name(), module()) :: :ok
  def register_publisher(table, name, module) do
    register(table, :publisher, name, module)
  end

  # Registers a module.
  @doc false
  @spec register(:ets.tab(), type(), name(), module()) :: :ok
  def register(table, type, name, module) do
    :ets.insert_new(table, {{type, name}, module})
    :ets.insert_new(table, {{type, module}, module})

    :ok
  end

  # Registers a global group.
  @doc false
  @spec register_global(:ets.tab(), atom()) :: :ok
  def register_global(table, name) do
    group = {table, name}
    pid = Process.whereis(__MODULE__)

    :pg2.create(group)

    with pids when is_list(pids) <- :pg2.get_local_members(group),
         true <- pid in pids do
      :ok
    else
      _ ->
        :pg2.join(group, pid)
        :ok
    end
  end

  ######################
  # Channel manipulation

  # Gets full channel.
  @doc false
  @spec get_full_channel(:ets.tab(), Channel.t()) ::
          {:ok, Channel.t()} | {:error, term()}
  def get_full_channel(table, %Channel{adapter: name} = channel) do
    with {:ok, node} <- get_adapter_node(table, name) do
      if node != node() do
        get_bridge_channel(table, channel)
      else
        get_local_channel(table, channel)
      end
    end
  end

  # Gets adapter node.
  @doc false
  @spec get_adapter_node(:ets.tab(), atom()) :: {:ok, node()} | {:error, term()}
  def get_adapter_node(table, name) do
    group = {table, name}

    with pid when is_pid(pid) <- :pg2.get_closest_pid(group) do
      {:ok, node(pid)}
    end
  end

  # Gets bridge channel.
  @doc false
  @spec get_bridge_channel(:ets.tab(), Channel.t()) ::
          {:ok, Channel.t()} | {:error, term()}
  def get_bridge_channel(table, %Channel{} = channel) do
    get_local_channel(table, %Channel{name: channel, adapter: :bridge})
  end

  # Gets local channel.
  @doc false
  @spec get_local_channel(:ets.tab(), Channel.t()) ::
          {:ok, Channel.t()} | {:error, term()}
  def get_local_channel(table, %Channel{adapter: adapter} = channel) do
    with {:ok, adapter} <- get_adapter_module(table, adapter),
         transformer = channel.transformer || adapter.get_transformer(),
         {:ok, _} <- get_transformer_module(table, transformer),
         backend = channel.backend || adapter.get_backend(),
         {:ok, _} <- get_backend_module(table, backend) do
      channel = %Channel{channel | transformer: transformer, backend: backend}

      {:ok, channel}
    end
  end

  ################
  # Module getters

  # Gets transformer module.
  @doc false
  @spec get_transformer_module(:ets.tab(), atom()) ::
          {:ok, module()} | {:error, term()}
  def get_transformer_module(table, name) do
    get_module(table, :transformer, name)
  end

  # Gets backend module.
  @doc false
  @spec get_backend_module(:ets.tab(), atom()) ::
          {:ok, module()} | {:error, term()}
  def get_backend_module(table, name) do
    get_module(table, :backend, name)
  end

  # Gets subscriber module.
  @doc false
  @spec get_subscriber_module(:ets.tab(), atom()) ::
          {:ok, module()} | {:error, term()}
  def get_subscriber_module(table, name) do
    get_module(table, :subscriber, name)
  end

  # Gets publisher module.
  @doc false
  @spec get_publisher_module(:ets.tab(), atom()) ::
          {:ok, module()} | {:error, term()}
  def get_publisher_module(table, name) do
    get_module(table, :publisher, name)
  end

  # Gets adapter module.
  @doc false
  @spec get_adapter_module(:ets.tab(), atom()) ::
          {:ok, module()} | {:error, term()}
  def get_adapter_module(table, name) do
    get_module(table, :adapter, name)
  end

  # Gets module.
  @doc false
  @spec get_module(:ets.tab(), type(), atom()) ::
          {:ok, module()} | {:error, term()}
  def get_module(table, type, name) do
    key = {type, name}

    case :ets.lookup(table, key) do
      [{^key, module} | _] ->
        {:ok, module}

      _ ->
        {:error, "Yggdrasil #{type}: #{name} not loaded"}
    end
  end
end
