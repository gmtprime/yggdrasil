defmodule Yggdrasil.RegistryTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Registry

  describe "register_transformer/2" do
    setup do
      assert :ok = Registry.register_transformer(:foo, Transformer)

      {:ok, name: :foo, module: Transformer}
    end

    test "registers transformer by name", %{name: name, module: module} do
      assert {:ok, ^module} = Registry.get_transformer_module(name)
    end

    test "registers transformer by module", %{module: module} do
      assert {:ok, ^module} = Registry.get_transformer_module(module)
    end
  end

  describe "register_backend/2" do
    setup do
      assert :ok = Registry.register_backend(:foo, Backend)

      {:ok, name: :foo, module: Backend}
    end

    test "registers backend by name", %{name: name, module: module} do
      assert {:ok, ^module} = Registry.get_backend_module(name)
    end

    test "registers backend by module", %{module: module} do
      assert {:ok, ^module} = Registry.get_backend_module(module)
    end
  end

  describe "register_adapter/2" do
    defmodule Adapter do
      def get_subscriber_module, do: {:ok, Subscriber}
      def get_publisher_module, do: {:ok, Publisher}
    end

    setup do
      assert :ok = Registry.register_adapter(:foo, Adapter)

      {:ok, name: :foo, module: Adapter}
    end

    test "registers adapter by name", %{name: name, module: module} do
      assert {:ok, ^module} = Registry.get_adapter_module(name)
    end

    test "registers adapter by module", %{module: module} do
      assert {:ok, ^module} = Registry.get_adapter_module(module)
    end

    test "registers adapter's subscriber", %{name: name, module: module} do
      {:ok, subscriber} = module.get_subscriber_module()

      assert {:ok, ^subscriber} = Registry.get_subscriber_module(name)
    end

    test "registers adapter's publisher", %{name: name, module: module} do
      {:ok, publisher} = module.get_publisher_module()

      assert {:ok, ^publisher} = Registry.get_publisher_module(name)
    end
  end
end
