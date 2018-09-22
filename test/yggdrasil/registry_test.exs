defmodule Yggdrasil.RegistryTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Channel
  alias Yggdrasil.Registry

  defmodule TestAdapter do
    use Yggdrasil.Adapter,
      name: :test_adapter,
      subscriber: TestSubscriber,
      publisher: TestPublisher
  end

  setup do
    opts = [:set, :public]
    {:ok, registry} = Registry.start_link(:test, opts, [])
    table = Registry.get(registry)

    {:ok, table: table}
  end

  describe "Registry.get/1" do
    test "creates the table" do
      opts = [:set, :public]
      assert {:ok, registry} = Registry.start_link(:test, opts, [])
      assert is_reference(Registry.get(registry))
      assert :ok = Registry.stop(registry)
    end
  end

  describe "Registry.register/4" do
    test "registers keys", %{table: table} do
      assert :ok = Registry.register(table, :key, :name, MyModule)
      assert {:ok, MyModule} = Registry.get_module(table, :key, :name)
      assert {:ok, MyModule} = Registry.get_module(table, :key, MyModule)
    end

    test "registers a key if the value is already set", %{table: table} do
      assert :ok = Registry.register(table, :key, :name, MyModule)
      assert :ok = Registry.register(table, :key, :name, MyModule)
    end

    test "prevents a key to be stored with different value", %{table: table} do
      assert :ok = Registry.register(table, :key, :name, MyModule)
      assert :error = Registry.register(table, :key, :name, MyOtherModule)
    end
  end

  describe "Registry.get_module/3" do
    setup context do
      :ok = Registry.register(context[:table], :key, :name, MyModule)
      :ok
    end

    test "gets a stored key by name", %{table: table} do
      assert {:ok, MyModule} = Registry.get_module(table, :key, :name)
    end

    test "gets a stored key by module", %{table: table} do
      assert {:ok, MyModule} = Registry.get_module(table, :key, MyModule)
    end

    test "errors when the key does not exist", %{table: table} do
      assert {:error, _} = Registry.get_module(table, :other_key, MyModule)
    end
  end

  describe "Registry.register_transformer/3" do
    test "registers a transformer", %{table: table} do
      assert :ok = Registry.register_transformer(table, :name, MyTransformer)
      assert {:ok, MyTransformer} =
             Registry.get_transformer_module(table, :name)
      assert {:ok, MyTransformer} =
             Registry.get_transformer_module(table, MyTransformer)
    end
  end

  describe "Registry.register_backend/3" do
    test "registers a backend", %{table: table} do
      assert :ok = Registry.register_backend(table, :name, MyBackend)
      assert {:ok, MyBackend} =
             Registry.get_backend_module(table, :name)
      assert {:ok, MyBackend} =
             Registry.get_backend_module(table, MyBackend)
    end
  end

  describe "Registry.register_adapter/3" do
    test "registers a adapter", %{table: table} do
      assert :ok = Registry.register_adapter(table, :test_adapter, TestAdapter)

      assert {:ok, TestSubscriber} =
             Registry.get_subscriber_module(table, :test_adapter)
      assert {:ok, TestSubscriber} =
             Registry.get_subscriber_module(table, TestSubscriber)

      assert {:ok, TestPublisher} =
             Registry.get_publisher_module(table, :test_adapter)
      assert {:ok, TestPublisher} =
             Registry.get_publisher_module(table, TestPublisher)

      assert {:ok, TestAdapter} =
             Registry.get_adapter_module(table, :test_adapter)
      assert {:ok, TestAdapter} =
             Registry.get_adapter_module(table, TestAdapter)
    end
  end

  describe "Registry.get_full_channel/2" do
    setup context do
      table = context[:table]
      :ok = Registry.register_adapter(table, :test_adapter, TestAdapter)
      :ok
    end

    test "generates a full channel", %{table: table}do
      channel = %Channel{name: "test_registry", adapter: :test_adapter}
      assert {
        :ok,
        %Channel{
          name: "test_registry",
          adapter: :test_adapter,
          transformer: :default,
          backend: :default,
          namespace: Yggdrasil
        }
      } = Registry.get_full_channel(table, channel)
    end
  end
end
