defmodule Yggdrasil.Registry do
  @moduledoc """
  Yggdrasil `Registry` for adapters, transformers and backends aliases.
  """
  use Agent

  alias Yggdrasil.Channel
  alias Yggdrasil.Settings

  @registry Settings.yggdrasil_module_registry()

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
  @spec get_transformer_module(
    atom() | module()
  ) :: {:ok, module()} | {:error, term()}
  def get_transformer_module(name) do
    get_transformer_module(@registry, name)
  end

  @doc """
  Gets the backend module for a `name`.
  """
  @spec get_backend_module(
    atom() | module()
  ) :: {:ok, module()} | {:error, term()}
  def get_backend_module(name) do
    get_backend_module(@registry, name)
  end

  @doc """
  Gets the subscriber module for a `name`.
  """
  @spec get_subscriber_module(
    atom() | module()
  ) :: {:ok, module()} | {:error, term()}
  def get_subscriber_module(name) do
    get_subscriber_module(@registry, name)
  end

  @doc """
  Gets the publisher module for a `name`.
  """
  @spec get_publisher_module(
    atom() | module()
  ) :: {:ok, module()} | {:error, term()}
  def get_publisher_module(name) do
    get_publisher_module(@registry, name)
  end

  @doc """
  Gets the adapter module for a `name`.
  """
  @spec get_adapter_module(
    atom() | module()
  ) :: {:ok, module()} | {:error, term()}
  def get_adapter_module(name) do
    get_adapter_module(@registry, name)
  end

  @doc """
  Gets full channel from the current `channel`.
  """
  @spec get_full_channel(
    channel :: Channel.t()
  ) :: {:ok, Channel.t} | {:error, term()}
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
    Agent.get(registry, fn table -> table end)
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
      full_channel = %Channel{channel |
        transformer: transformer,
        backend: backend
      }
      {:ok, full_channel}
    end
  end
end
