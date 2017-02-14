defmodule Yggdrasil.VirtualAdapter do
  @moduledoc """
  Behaviour to implement virtual adapters that serve as both
  subscribing/unsubscribing and publishing.
  """

  @doc """
  Callback to return the module for publishing.
  """
  @callback get_server_adapter() :: {:ok, module} | {:error, term}

  @doc """
  Callback to return the module for subscribing/unsubscribing.
  """
  @callback get_client_adapter() :: {:ok, module} | {:error, term}

  defmacro __using__(_) do
    quote do
      @behavoiur Yggdrasil.VirtualAdapter

      @doc false
      def get_server_adapter do
        {:error, "Virtual adapter not defined"}
      end

      @doc false
      def get_client_adapter do
        {:error, "Virtual adapter not defined"}
      end

      defoverridable [get_server_adapter: 0, get_client_adapter: 0]
    end
  end
end

defmodule Yggdrasil.Elixir do
  use Yggdrasil.VirtualAdapter

  @doc false
  def get_server_adapter do
    {:ok, Yggdrasil.Publisher.Adapter.Elixir}
  end

  @doc false
  def get_client_adapter do
    {:ok, Yggdrasil.Distributor.Adapter.Elixir}
  end
end

defmodule Yggdrasil.Redis do
  use Yggdrasil.VirtualAdapter

  @doc false
  def get_server_adapter do
    {:ok, Yggdrasil.Publisher.Adapter.Redis}
  end

  @doc false
  def get_client_adapter do
    {:ok, Yggdrasil.Distributor.Adapter.Redis}
  end
end

defmodule Yggdrasil.RabbitMQ do
  use Yggdrasil.VirtualAdapter

  @doc false
  def get_server_adapter do
    {:ok, Yggdrasil.Publisher.Adapter.RabbitMQ}
  end

  @doc false
  def get_client_adapter do
    {:ok, Yggdrasil.Distributor.Adapter.RabbitMQ}
  end
end

defmodule Yggdrasil.Postgres do
  use Yggdrasil.VirtualAdapter

  @doc false
  def get_server_adapter do
    {:ok, Yggdrasil.Publisher.Adapter.Postgres}
  end

  @doc false
  def get_client_adapter do
    {:ok, Yggdrasil.Distributor.Adapter.Postgres}
  end
end
