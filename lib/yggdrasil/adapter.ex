defmodule Yggdrasil.Registry do
  @moduledoc """
  Yggdrasil `Registry` for adapters, transformers and backends aliases.
  """
  use Agent

  @registry :yggdrasil_registry

  @doc """
  Starts a registry with some optional `options`
  """
  @spec start_link() :: Agent.on_start()
  @spec start_link(Agent.options()) :: Agent.on_start()
  def start_link(options \\ []) do
    start_link(@registry, options)
  end

  @doc """
  Stops a `registry` with optionals `reason` and `timeout`.
  """
  defdelegate stop, to: Agent, as: :stop

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

  #########
  # Helpers

  @doc false
  def start_link(table, options) do
    opts = [
      :set,
      :named_table,
      :public,
      write_concurrency: true,
      read_concurrency: true
    ]
    Agent.start_link(fn -> :ets.new(table, opts) end, options)
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
         :ok <-register_publisher(table, name, publisher) do
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
  def register(table, key, name, module)
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
end

defmodule Yggdrasil.Transformer do
  @moduledoc """
  Transformer behaviour. Defines how to decode and encode messages from a
  `Yggdrasil.Channel`.

  ## Small example

  Let's say we want to implement a transformer to send any Elixir term as a
  string to our subscribers. The transformer module would be implemented as
  follows:

  ```
  defmodule Yggdrasil.Transformer.Code do
    use Yggdrasil.Transformer

    def decode(_channel, message) do
      with {decoded, []} <- Code.eval_string(message) do
        {:ok, decoded}
      else
        _ ->
          {:error, "Bad message"}
      end
    end

    def encode(_channel, message) do
      encoded = inspect(message)
      {:ok, encoded}
    end
  end
  ```

  And we could use the following `Channel` to publish or subscribe to this
  messages:

  ```
  %Channel{
    name: "my_channel",
    adapter: :redis,
    transformer: Yggdrasil.Transformer.Code
  }
  ```

  ## Transformer alias

  When defining transformers it is possible to define aliases for the module
  as follows:

  ```
  defmodule Yggdrasil.Transformer.Code do
    use Yggdrasil.Transformer, name: :code

    (... same implementation as above ...)
  end
  ```

  And adding the following to our application supervision tree:

  ```
  Supervisor.start_link([
    {Yggdrasil.Transformer.Code, []}
    ...
  ])
  ```

  This will allow you to use the following as a `Channel` to subscribe and
  publish:

  ```
  %Channel{name: "my_channel", adapter: :redis, transformer: :code}
  ```
  """
  alias Yggdrasil.Channel
  alias Yggdrasil.Registry, as: Reg

  @doc """
  Callback to define how to decode the messages coming from a distributor
  adapter.
  """
  @callback decode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}

  @doc """
  Callback to define how to encode the messages coming from a publisher
  adapter.
  """
  @callback encode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}

  defmacro __using__(options) do
    transformer_alias = Keyword.get(options, :name)

    quote do
      @behaviour Yggdrasil.Transformer
      alias Yggdrasil.Registry, as: Reg

      use Task, restart: :transient

      @doc false
      def start_link do
        Task.start_link(__MODULE__, :register, [])
      end

      @doc false
      def register do
        name = unquote(transformer_alias)
        with :ok <- Reg.register_transformer(name, __MODULE__) do
          :ok
        else
          :error ->
            exit(:error)
        end
      end

      @doc false
      def decode(_channel, message) do
        {:ok, message}
      end

      @doc false
      def encode(_channel, message) do
        {:ok, message}
      end

      defoverridable [decode: 2, encode: 2]
    end
  end

  @doc """
  Generic `message` decoder for a `channel`.
  """
  @spec decode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}
  def decode(channel, message)

  def decode(%Channel{transformer: name} = channel, message) do
    with {:ok, module} <- Reg.get_transformer_module(name) do
      module.decode(channel, message)
    end
  end

  @doc """
  Generic `message` encoder for a `channel`.
  """
  @spec encode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}
  def encode(channel, message)

  def encode(%Channel{transformer: name} = channel, message) do
    with {:ok, module} <- Reg.get_transformer_module(name) do
      module.encode(channel, message)
    end
  end
end

defmodule Yggdrasil.Backend do
  # TODO Backend behaviour
  defmacro __using__(options) do
    backend_alias = Keyword.get(options, :name)
    quote do
      @behaviour Yggdrasil.Backend
      alias Yggdrasil.Registry, as: Reg

      use Task, restart: :transient

      @doc false
      def start_link do
        Task.start_link(__MODULE__, :register, [])
      end

      @doc false
      def register do
        name = unquote(backend_alias)
        with :ok <- Reg.register_backend(name, __MODULE__) do
          :ok
        else
          :error ->
            exit(:error)
        end
      end
    end
  end
end

defmodule Yggdrasil.Subscriber.Adapter do
  # TODO Behaviour
end

defmodule Yggdrasil.Publisher.Adapter do
  # TODO Behaviour
end

defmodule Yggdrasil.Adapter do
  @moduledoc """
  This module defines a generalization of an adapter (for adapter creation
  refer to `Yggdrasil.Subscriber.Adapter` and `Yggdrasil.Publisher.Adapter`
  behaviour).

  ## Adapter alias

  If you already have implemented the publisher and subscriber adapters, then
  you can alias the module names in order to publish and subscribe using the
  same `Channel` struct.

  Let's say that you have both `Yggdrasil.Publisher.Adapter.MyAdapter` and
  `Yggdrasil.Subscriber.Adapter.MyAdapter` and you want to alias both of this
  modules to `:my_adapter`, the you would do the following:

  ```
  defmodule Yggdrasil.Adapter.MyAdapter do
    use Yggdrasil.Adapter,
      name: :my_adapter,
      subscriber: Yggdrasil.Subscriber.Adapter.MyAdapter,
      publisher: Yggdrasil.Publisher.Adapter.MyAdapter
  end
  ```

  And adding the following to your application supervision tree:

  ```
  Supervisor.start_link([
    {Yggdrasil.Adapter.MyAdapter, []}
    ...
  ])
  ```

  This will allow you to use the following as a `Channel` to subscribe and
  publish with your adapters:

  ```
  %Channel{name: "my_channel", adapter: :my_adapter}
  ```
  """

  @doc """
  Macro for using the adapter module.

  The following are the available options:
  - `:name` - Name of the adapter. Must be an atom.
  - `:transformer` - Default transformer module or alias. Defaults to
  `:default`
  - `:backend` - Default backend module or alias. Defaults to `:default`.
  - `:subscriber` - Subscriber module. Defaults to
  `Yggdrasil.Subscriber.Adapter.<NAME>` where `<NAME>` is the last part of the
  current module name e.g. the `<NAME>` for `Yggdrasil.MyAdapter` would be
  `MyAdapter`. If the module does not exist, then defaults to `:elixir`.
  - `:publisher` - Publisher module. Defaults to
  `Yggdrasil.Publisher.Adapter.<NAME>` where `<NAME>` is the last part of the
  current module name e.g. the `<NAME>` for `Yggdrasil.MyAdapter` would be
  `MyAdapter`. If the module does not exist, then defaults to `:elixir`.
  """
  defmacro __using__(options) do
    adapter_alias = Keyword.get(options, :name)
    transformer_alias = Keyword.get(options, :transformer, :default)
    backend_alias = Keyword.get(options, :backend, :default)

    subscriber_module = Keyword.get(options, :subscriber)
    publisher_module = Keyword.get(options, :publisher)

    quote do
      use Task, restart: :transient

      alias Yggdrasil.Registry, as: Reg

      @doc false
      def start_link do
        Task.start_link(__MODULE__, :register, [])
      end

      @doc false
      def register do
        name = unquote(adapter_alias)
        with :ok <- Reg.register_adapter(name, __MODULE__) do
          :ok
        else
          :error ->
            exit(:error)
        end
      end

      #############
      # Transformer

      @doc false
      def get_transformer do
        unquote(transformer_alias)
      end

      #########
      # Backend

      @doc false
      def get_backend do
        unquote(backend_alias)
      end

      ############
      # Subscriber

      @doc false
      def get_subscriber_module do
        get_subscriber_module(unquote(subscriber_module))
      end

      @doc false
      def get_subscriber_module(nil) do
        base = "Elixir.Yggdrasil.Subscriber.Adapter"
        name =
          __MODULE__
          |> Atom.to_string()
          |> String.split(".")
          |> List.last()
        try do
          String.to_existing_atom(base <> "." <> name)
        catch
          {:error, :badarg} ->
            :elixir
        end
      end
      def get_subscriber_module(module) when is_atom(module) do
        module
      end

      ###########
      # Publisher

      @doc false
      def get_publisher_module do
        get_publisher_module(unquote(publisher_module))
      end

      @doc false
      def get_publisher_module(nil) do
        base = "Elixir.Yggdrasil.Publisher.Adapter"
        name =
          __MODULE__
          |> Atom.to_string()
          |> String.split(".")
          |> List.last()
        try do
          String.to_existing_atom(base <> "." <> name)
        catch
          {:error, :badarg} ->
            :elixir
        end
      end
      def get_publisher_module(module) when is_atom(module) do
        module
      end
    end
  end

  @doc """
  Generic subscriber adapter starter that receives a `channel`, a `publisher`
  and an optional `GenServer` options.
  """
  @spec start_subscriber(
    Channel.t(),
    term()
  ) :: GenServer.on_start()
  @spec start_subscriber(
    Channel.t(),
    term(),
    GenServer.options()
  ) :: GenServer.on_start()
  def start_subscriber(channel, publisher, options \\ [])

  def start_subscriber(
    %Channel{adapter: adapter} = channel,
    publisher,
    options
  ) do
    with {:ok, module} <- Reg.get_subscriber_module(adapter) do
      module.start_link(channel, publisher, options)
    end
  end

  @doc """
  Generic subscriber adapter stopper that receives the `pid`.
  """
  @spec stop_subscriber(GenServer.name()) :: :ok
  def stop_subscriber(pid) do
    GenServer.stop(pid)
  end

  @doc """
  Generic publisher adapter starter that receives a `channel` and an optional
  `GenServer` options.
  """
  @spec start_publisher(Channel.t()) :: GenServer.on_start()
  @spec start_publisher(
    Channel.t(),
    GenServer.options()
  ) :: GenServer.on_start()
  def start_publisher(channel, options \\ [])

  def start_publisher(
    %Channel{
      adapter: adapter,
      namespace: namespace
    },
    options
  ) do
    with {:ok, module} <- Reg.get_publisher_module(adapter) do
      module.start_link(namespace, options)
    end
  end

  @doc """
  Generic subscriber adapter stopper that receives the `pid`.
  """
  @spec stop_publisher(GenServer.name()) :: :ok
  def stop_publisher(pid) do
    GenServer.stop(pid)
  end
end

defmodule Yggdrasil.Adapter.Elixir do
  use Yggdrasil.Adapter, name: :elixir
end

defmodule Yggdrasil.Transformer.Default do
  use Yggdrasil.Transformer, name: :default
end

defmodule Yggdrasil.Backend.Default do
  use Yggdrasil.Transformer, name: :default
end
