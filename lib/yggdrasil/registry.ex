defmodule Yggdrasil.Registry do
  @moduledoc """
  Yggdrasil `Registry` for adapters, transformers and backends aliases.
  """
  use Agent

  # PG2 : {:"$yggdrasil_registry", :transformer, name} : pid => node
  # PG2 : {:"$yggdrasil_registry", :backend, name}     : pid => node
  # PG2 : {:"$yggdrasil_registry", :adapter, name}     : pid => node
  #
  # ETS : {:transformer, name} : module
  # ETS : {:backend, name}     : module
  # ETS : {:subscriber, name}  : module
  # ETS : {:publisher, name}   : module
  #
  # :rpc.call(node, module, <function>, [<arg>, ...])
  alias __MODULE__
  alias Yggdrasil.Channel
  alias Yggdrasil.Settings

  @module_registry Settings.module_registry!()

  @type type :: :transformer | :backend | :subscriber | :publisher | :adapter

  ######################
  # Registration helpers

  # Registers a transformer.
  @doc false
  @spec register_transformer(:ets.tab(), atom(), module()) :: :ok
  def register_transformer(table, name, module) do
    register(table, :transformer, name, module)
  end

  # Registers a backend.
  @doc false
  @spec register_backend(:ets.tab(), atom(), module()) :: :ok
  def register_backend(table, name, module) do
    register(table, :backend, name, module)
  end

  # Registers an adapter.
  @doc false
  @spec register_adapter(:ets.tab(), atom(), module()) ::
          :ok | {:error, term()}
  def register_adapter(table, name, module) do
    with {:ok, subscriber} <- module.get_subscriber_module(),
         {:ok, publisher} <- module.get_publisher_module(),
         :ok <- register_subscriber(table, name, subscriber),
         :ok <- register_publisher(table, name, publisher) do
      register(table, :adapter, name, module)
    end
  end

  # Registers a subscriber.
  @doc false
  @spec register_subscriber(:ets.tab(), atom(), module()) :: :ok
  def register_subscriber(table, name, subscriber) do
    register(table, :subscriber, name, subscriber)
  end

  # Registers a publisher.
  @doc false
  @spec register_publisher(:ets.tab(), atom(), module()) :: :ok
  def register_publisher(table, name, publisher) do
    register(table, :publisher, name, publisher)
  end

  # Registers a module.
  @doc false
  @spec register(:ets.tab(), type(), atom(), module()) :: :ok
  def register(table, type, name, module) do
    register_global(table, type, name)
    register_global(table, type, module)

    :ets.insert_new(table, {{type, name}, module})
    :ets.insert_new(table, {{type, module}, module})

    :ok
  end

  # Registers a global group.
  @doc false
  @spec register_global(:ets.tab(), type(), atom()) :: :ok
  def register_global(table, type, name) do
    group = {table, type, name}
    pid = self()

    :pg2.create(group)

    case :pg2.get_local_members(group) do
      pids when pid in pids ->
        :ok
      _ ->
        :pg2.join(group, pid)
        :ok
    end
  end

  ################
  # Module helpers

  # Gets transformer module.
  @doc false
  @spec get_transformer_module(table, name) ::
          {:ok, module()}
          | {:ok, {node(), module()}}
          | {:error, term()}
  def get_transformer_module(table, name) do
    get_module(table, :transformer, name)
  end

  # Gets backend module.
  @doc false
  @spec get_backend_module(table, name) ::
          {:ok, module()}
          | {:ok, {node(), module()}}
          | {:error, term()}
  def get_backend_module(table, name) do
    get_module(table, :backend, name)
  end

  # Gets subscriber module.
  @doc false
  @spec get_subscriber_module(table, name) ::
          {:ok, module()}
          | {:ok, {node(), module()}}
          | {:error, term()}
  def get_subscriber_module(table, name) do
    get_module(table, :subscriber, name)
  end

  # Gets publisher module.
  @doc false
  @spec get_publisher_module(table, name) ::
          {:ok, module()}
          | {:ok, {node(), module()}}
          | {:error, term()}
  def get_publisher_module(table, name) do
    get_module(table, :publisher, name)
  end

  # Gets adapter module.
  @doc false
  @spec get_adapter_module(table, name) ::
          {:ok, module()}
          | {:ok, {node(), module()}}
          | {:error, term()}
  def get_adapter_module(table, name) do
    get_module(table, :adapter, name)
  end

  # Gets module.
  @doc false
  @spec get_module(:ets.tab(), type(), atom()) ::
          {:ok, module()}
          | {:ok, {node(), module()}}
          | {:error, term()}
  def get_module(table, type, name) do
    with {:ok, module_node} <- get_node(table, type, name) do
      do_get_remote_module(module_node, table, type, name)
    end
  end

  # Gets node.
  @doc false
  @spec get_node(:ets.tab(), type(), atom()) ::
          {:ok, node()} | {:error, term()}
  def get_node(table, type, name) do
    group = {table, type, name}

    with pid when is_pid(pid) <- :pg2.get_closest_pid(group) do
      {:ok, node(pid)}
    end
  end

  # Gets remote module.
  @doc false
  @spec do_get_remote_module(node(), :ets.tab(), type(), atom()) ::
          {:ok, module()}
          | {:ok, {node(), module()}}
          | {:error, term()}
  def do_get_remote_module(node, table, type, name) do
    args = [table, type, name]

    case :rpc.call(node, Registry, :do_get_module, args) do
      {:ok, module} ->
        if node() == node do
          {:ok, module}
        else
          {:ok, {node, module}}
        end

      _ ->
        {:error, "Yggdrasil #{type}: #{name} not loaded"}
    end
  end

  # Gets local module.
  @doc false
  @spec do_get_module(:ets.tab(), type(), atom()) ::
          {:ok, module()} | {:error, term()}
  def do_get_module(table, type, name) do
    key = {type, name}

    case :ets.lookup(table, key) do
      [{^key, module} | _] ->
        {:ok, module}

      _ ->
        {:error, "Yggdrasil #{type}: #{name} not loaded"}
    end
  end

  ##############
  # Full channel

  @doc false
  def get_full_channel(table, %Channel{adapter: adapter_name} = channel) do
    with {:ok, adapter} <- get_adapter_module(table, adapter_name),
         {:ok, transformer} <- get_transformer(table, channel, adapter),
         {:ok, backend} <- get_backend(table, channel, adapter) do
      full_channel = %Channel{
        channel
        | adapter: adapter,
          transformer: transformer,
          backend: backend
      }

      {:ok, full_channel}
    end
  end

  # Gets transformer.
  @doc false
  @spec get_transformer(
          :ets.tab(),
          Channel.t(),
          module() | {node(), module()}
        ) :: {:ok, module()} | {:ok, {node(), module()}} | {:error, term()}
  def get_transformer(table, channel, adapter)

  def get_transformer(_table, %Channel{transformer: nil}, adapter) do
    {:ok, run(adapter, :get_transformer, [])}
  end

  def get_transformer(table, %Channel{transformer: transformer}, _adapter) do
    get_transformer_module(table, transformer)
  end

  # Gets backend.
  @doc false
  @spec get_backend(
          :ets.tab(),
          Channel.t(),
          module() | {node(), module()}
        ) :: {:ok, module()} | {:ok, {node(), module()}} | {:error, term()}
  def get_backend(table, channel, adapter)

  def get_backend(_table, %Channel{backend: nil}, adapter) do
    {:ok, run(adapter, :get_backend, [])}
  end

  def get_transformer(table, %Channel{backend: backend}, _adapter) do
    get_backend_module(table, backend)
  end

  # Run a function remotely or locally.
  @doc false
  @spec run(module() | {node(), module()}, atom(), list()) ::
          term() | no_return()
  def run({node, module}, function, args) do
    case :rpc.call(node, module, function, args) do
      {:badrpc, _} = error -> exit(error)
      result -> result
    end
  end

  def run(module, function, args) do
    apply(module, function, args)
  end

  #####################33
  # OLD

  @registry Settings.yggdrasil_module_registry!()

  @doc """
  Starts a registry with some optional `options`
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

    start_link(@registry, opts, options)
  end

  @doc """
  Stops a `registry` with optionals `reason` and `timeout`.
  """
  defdelegate stop(agent), to: Agent, as: :stop

  @doc """
  Registers a transformer `module` as a `name`.
  """
  @spec register_transformer(atom(), module()) :: :ok | :error
  def register_transformer(name, module) do
    register_transformer(@registry, name, module)
  end

  @doc """
  Registers a backend `module` as a `name`.
  """
  @spec register_backend(atom(), module()) :: :ok | :error
  def register_backend(name, module) do
    register_backend(@registry, name, module)
  end

  @doc """
  Registers an adapter `module` as `name`.
  """
  @spec register_adapter(atom(), atom() | module()) :: :ok | :error
  def register_adapter(name, module) do
    register_adapter(@registry, name, module)
  end

  @doc """
  Gets the transformer module for a `name`.
  """
  @spec get_transformer_module(atom() | module()) ::
          {:ok, module()} | {:error, term()}
  def get_transformer_module(name) do
    get_transformer_module(@registry, name)
  end

  @doc """
  Gets the backend module for a `name`.
  """
  @spec get_backend_module(atom() | module()) ::
          {:ok, module()} | {:error, term()}
  def get_backend_module(name) do
    get_backend_module(@registry, name)
  end

  @doc """
  Gets the subscriber module for a `name`.
  """
  @spec get_subscriber_module(atom() | module()) ::
          {:ok, module()} | {:error, term()}
  def get_subscriber_module(name) do
    get_subscriber_module(@registry, name)
  end

  @doc """
  Gets the publisher module for a `name`.
  """
  @spec get_publisher_module(atom() | module()) ::
          {:ok, module()} | {:error, term()}
  def get_publisher_module(name) do
    get_publisher_module(@registry, name)
  end

  @doc """
  Gets the adapter module for a `name`.
  """
  @spec get_adapter_module(atom() | module()) ::
          {:ok, module()} | {:error, term()}
  def get_adapter_module(name) do
    get_adapter_module(@registry, name)
  end

  @doc """
  Gets full channel from the current `channel`.
  """
  @spec get_full_channel(channel :: Channel.t()) ::
          {:ok, Channel.t()} | {:error, term()}
  def get_full_channel(channel) do
    get_full_channel(@registry, channel)
  end

  #########
  # Helpers

  @doc false
  def start_link(table, table_opts, options) do
    Agent.start_link(fn -> :ets.new(table, table_opts) end, options)
  end

  @doc false
  def get(registry) do
    Agent.get(registry, & &1)
  end

  @doc false
  def register_transformer(table, name, module) do
    register(table, :transformer, name, module)
  end

  @doc false
  def register_backend(table, name, module) do
    register(table, :backend, name, module)
  end

  @doc false
  def register_adapter(table, name, module) do
    subscriber = module.get_subscriber_module()
    publisher = module.get_publisher_module()

    with :ok <- register_subscriber(table, name, subscriber),
         :ok <- register_publisher(table, name, publisher) do
      register(table, :adapter, name, module)
    end
  end

  @doc false
  def register_subscriber(table, name, subscriber) do
    case :ets.lookup(table, {:subscriber, subscriber}) do
      [] ->
        register(table, :subscriber, name, subscriber)

      [{_, module} | _] ->
        register(table, :subscriber, name, module)
    end
  end

  @doc false
  def register_publisher(table, name, publisher) do
    case :ets.lookup(table, {:publisher, publisher}) do
      [] ->
        register(table, :publisher, name, publisher)

      [{_, module} | _] ->
        register(table, :publisher, name, module)
    end
  end

  @doc false
  def register(table, key, name, module) do
    with true <- :ets.insert_new(table, {{key, name}, module}),
         true <- :ets.insert_new(table, {{key, module}, module}) do
      :ok
    else
      false ->
        case :ets.lookup(table, {key, name}) do
          [{_, ^module} | _] ->
            :ok

          [{_, _} | _] ->
            :error

          _ ->
            :error
        end
    end
  end

  @doc false
  def get_transformer_module(table, name) do
    get_module(table, :transformer, name)
  end

  @doc false
  def get_backend_module(table, name) do
    get_module(table, :backend, name)
  end

  @doc false
  def get_subscriber_module(table, name) do
    get_module(table, :subscriber, name)
  end

  @doc false
  def get_publisher_module(table, name) do
    get_module(table, :publisher, name)
  end

  @doc false
  def get_adapter_module(table, name) do
    get_module(table, :adapter, name)
  end

  @doc false
  def get_module(table, key, name) do
    case :ets.lookup(table, {key, name}) do
      [] ->
        {:error, "Yggdrasil #{key} :#{name} not found"}

      [{_, module} | _] ->
        {:ok, module}
    end
  end

  @doc false
  def get_full_channel(table, %Channel{adapter: adapter_name} = channel) do
    with {:ok, adapter} <- get_adapter_module(table, adapter_name) do
      transformer = channel.transformer || adapter.get_transformer()
      backend = channel.backend || adapter.get_backend()

      full_channel = %Channel{
        channel
        | transformer: transformer,
          backend: backend
      }

      {:ok, full_channel}
    end
  end
end
