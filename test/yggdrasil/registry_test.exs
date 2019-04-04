defmodule Yggdrasil.RegistryTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Registry

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
      assert {:ok, MyBackend} = Registry.get_backend_module(table, :name)
      assert {:ok, MyBackend} = Registry.get_backend_module(table, MyBackend)
    end
  end
end
