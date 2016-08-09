defmodule Yggdrasil.Decoder do
  @moduledoc """
  Decoder behaviour. Defines the adapter and the decoding function from the
  messages received from the adapter. By default, the adapter is
  `Yggdrasil.Adapter.Elixir`
  """

  @doc """
  Callback to define how to decode the messages received from the adapter.
  Receives the `channel` and the `message`. It returns an arbitrary term.
  """
  @callback decode(channel, message) :: term
    when channel: YProcess.channel, message: term

  defmacro __using__(opts \\ []) do
    adapter = Keyword.get(opts, :adapter, Yggdrasil.Adapter.Elixir)
    quote do
      @behaviour Yggdrasil.Decoder

      @doc """
      Gets the adapter.
      """
      def get_adapter, do: unquote(adapter)

      @doc """
      Default decoder. It does not change the `message` and ignores the
      `channel`.
      """
      def decode(_channel, message), do: message

      defoverridable [decode: 2] 
    end
  end
end

defmodule Yggdrasil.Decoder.Default do
  @moduledoc """
  Default decoder.
  """
  use Yggdrasil.Decoder
end

defmodule Yggdrasil.Decoder.Default.Redis do
  @moduledoc """
  Default decoder for Redis.
  """
  use Yggdrasil.Decoder, adapter: Yggdrasil.Adapter.Redis
end

defmodule Yggdrasil.Decoder.Default.RabbitMQ do
  @moduledoc """
  Default decoder for RabbitMQ.
  """
  use Yggdrasil.Decoder, adapter: Yggdrasil.Adapter.RabbitMQ
end

defmodule Yggdrasil.Decoder.Default.Postgres do
  @moduledoc """
  Default decoder for Postgres.
  """
  use Yggdrasil.Decoder, adapter: Yggdrasil.Adapter.Postgres
end
