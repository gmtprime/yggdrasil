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
    use Yggdrasil.Adapter, name: :my_adapter
  end
  ```

  And adding the following to your application supervision tree:

  ```
  Supervisor.start_link([
    {Yggdrasil.Adapter.MyAdapter, []}
    ...
  ])
  ```

  This will allow you to use `:my_adapter` as a `Channel` adapter to subscribe
  and publish with `MyAdapter` e.g:

  ```
  %Channel{name: "my_channel", adapter: :my_adapter}
  ```
  """
  alias __MODULE__
  alias Yggdrasil.Registry

  @doc """
  Macro for using `Yggdrasil.Adapter`.

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

      @doc """
      Start task to register the adapter in the `Registry.
      """
      @spec start_link(term()) :: {:ok, pid()}
      def start_link(_) do
        Task.start_link(__MODULE__, :register, [])
      end

      @doc """
      Registers adapter in `Registry`.
      """
      @spec register() :: :ok | no_return()
      def register do
        name = unquote(adapter_alias)

        case Registry.register_adapter(name, __MODULE__) do
          :ok -> :ok
          :error -> exit(:error)
        end
      end

      @doc """
      Gets default transformer.
      """
      @spec get_transformer() :: atom()
      def get_transformer do
        unquote(transformer_alias)
      end

      @doc """
      Gets default backend.
      """
      @spec get_backend() :: atom()
      def get_backend do
        unquote(backend_alias)
      end

      @doc """
      Gets subscriber module.
      """
      @spec get_subscriber_module() :: {:ok, module()} | {:error, term()}
      def get_subscriber_module do
        get_subscriber_module(unquote(subscriber_module))
      end

      @doc """
      Gets subscriber module only if the given module exists.
      """
      @spec get_subscriber_module(nil | module()) ::
              {:ok, module()} | {:error, term()}
      def get_subscriber_module(module)

      def get_subscriber_module(nil) do
        type = Subscriber

        with {:ok, module} <- Adapter.generate_module(__MODULE__, type) do
          get_subscriber_module(module)
        end
      end

      def get_subscriber_module(module) do
        Adapter.check_module(__MODULE__, module)
      end

      @doc """
      Gets publisher module.
      """
      @spec get_publisher_module() :: {:ok, module()} | {:error, term()}
      def get_publisher_module do
        get_publisher_module(unquote(publisher_module))
      end

      @doc """
      Gets publisher module only if the given module exists.
      """
      @spec get_publisher_module(nil | module()) ::
              {:ok, module()} | {:error, term()}
      def get_publisher_module(module)

      def get_publisher_module(nil) do
        type = Publisher

        with {:ok, module} <- Adapter.generate_module(__MODULE__, type) do
          get_publisher_module(module)
        end
      end

      def get_publisher_module(module) do
        Adapter.check_module(__MODULE__, module)
      end
    end
  end

  @typedoc """
  Adapter types.
  """
  @type type :: Subscriber | Publisher

  @types [Subscriber, Publisher]

  @doc """
  Generates module given an `adapter` module and a `type`.
  """
  @spec generate_module(module(), type()) :: {:ok, module()} | {:error, term()}
  def generate_module(adapter, type)

  def generate_module(adapter, type) when type in @types do
    base = Module.split(adapter)

    case Enum.split_while(base, & &1 != "Adapter") do
      {[], _} ->
        {:error, "Cannot generate #{type} module for #{adapter}"}

      {_, []} ->
        {:error, "Cannot generate #{type} module for #{adapter}"}

      {prefix, suffix} ->
        module = Module.concat(prefix ++ [to_string(type) | suffix])
        {:ok, module}
    end
  end

  @doc """
  Checks that the module exists.
  """
  @spec check_module(module(), module()) :: {:ok, module()} | {:error, term()}
  def check_module(adapter, module)

  def check_module(adapter, module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} ->
        {:ok, module}

      _ ->
        {:error, "Cannot find #{module} for #{adapter}"}
    end
  end
end
