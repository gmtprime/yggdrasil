defmodule Yggdrasil.Transformer do
  @moduledoc """
  Transformer behaviour. Defines how to decode and encode messages from a
  `Yggdrasil.Channel`.
  """
  alias Yggdrasil.Channel

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

  defmacro __using__(_) do
    quote do
      @behaviour Yggdrasil.Transformer

      @doc false
      def decode(_channel, message) do
        {:ok, message}
      end

      @doc false
      def encode(_channel, message) when is_binary(message) do
        {:ok, message}
      end
      def encode(_channel, data) do
        encoded = inspect data
        {:ok, encoded}
      end

      defoverridable [decode: 2, encode: 2]
    end
  end
end

defmodule Yggdrasil.Transformer.Default do
  @moduledoc """
  Default Yggdrasil transformer.
  """
  use Yggdrasil.Transformer
end
