defmodule Yggdrasil.Transformer do
  @moduledoc """
  Transformer behaviour that defines how to decode and encode messages from a
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
  alias Yggdrasil.Registry

  @doc """
  Callback to define how to decode the `message`s coming from a `channel`.
  """
  @callback decode(
              channel :: Channel.t(),
              message :: term()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  Callback to define how to encode the `message`s going to a `channel`.
  """
  @callback encode(
              channel :: Channel.t(),
              message :: term()
            ) :: {:ok, term()} | {:error, term()}

  @doc """
  Macro for using `Yggdrasil.Transformer`.

  The following are the available options:
  - `:name` - Name of the transformer. Must be an atom.
  """
  defmacro __using__(options) do
    transformer_alias =
      options[:name] || raise ArgumentError, message: "transformer not found"

    quote do
      @behaviour Yggdrasil.Transformer

      use Task, restart: :transient

      @doc """
      Start task to register the transformer in the `Registry`.
      """
      @spec start_link(term()) :: {:ok, pid()}
      def start_link(_) do
        Task.start_link(__MODULE__, :register, [])
      end

      @doc """
      Registers transformer in `Registry`.
      """
      @spec register() :: :ok
      def register do
        name = unquote(transformer_alias)

        Registry.register_transformer(name, __MODULE__)
      end

      @doc """
      Decodes a `message` for a `channel`.
      """
      @spec decode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}
      @impl true
      def decode(channel, message)

      def decode(%Channel{} = _channel, message) do
        {:ok, message}
      end

      def decode(_channel, _message) do
        {:error, "invalid channel"}
      end

      @doc """
      Encodes a `message` for a `channel`.
      """
      @spec encode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}
      @impl true
      def encode(channel, message)

      def encode(%Channel{} = _channel, message) do
        {:ok, message}
      end

      def encode(_channel, _message) do
        {:error, "invalid channel"}
      end

      defoverridable decode: 2, encode: 2
    end
  end

  @doc """
  Generic `message` decoder for a `channel`.
  """
  @spec decode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}
  def decode(channel, message)

  def decode(%Channel{transformer: name} = channel, message) do
    with {:ok, module} <- Registry.get_transformer_module(name) do
      module.decode(channel, message)
    end
  end

  @doc """
  Generic `message` encoder for a `channel`.
  """
  @spec encode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}
  def encode(channel, message)

  def encode(%Channel{transformer: name} = channel, message) do
    with {:ok, module} <- Registry.get_transformer_module(name) do
      module.encode(channel, message)
    end
  end
end
