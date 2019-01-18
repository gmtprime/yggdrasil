defmodule Yggdrasil.AdapterTest do
  use ExUnit.Case, async: true

  alias Yggdrasil.Adapter.Elixir, as: Default

  defmodule TestAdapter do
    use Yggdrasil.Adapter,
      name: :test_adapter,
      transformer: :some_transformer,
      backend: :some_backend,
      subscriber: :some_subscriber,
      publisher: :some_publisher
  end

  describe "Adapter behaviour" do
    test "gets transformer" do
      assert :some_transformer = TestAdapter.get_transformer()
    end

    test "gets backend" do
      assert :some_backend = TestAdapter.get_backend()
    end

    test "gets subscriber module" do
      assert :some_subscriber = TestAdapter.get_subscriber_module()
    end

    test "gets publisher module" do
      assert :some_publisher = TestAdapter.get_publisher_module()
    end
  end

  describe "Elixir adapter" do
    test "gets default transformer" do
      assert :default = Default.get_transformer()
    end

    test "gets default backend" do
      assert :default = Default.get_backend()
    end

    test "gets subscriber module" do
      assert Yggdrasil.Subscriber.Adapter.Elixir =
               Default.get_subscriber_module()
    end

    test "gets publisher module" do
      assert Yggdrasil.Publisher.Adapter.Elixir = Default.get_publisher_module()
    end
  end
end
