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
end
