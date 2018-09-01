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
  alias Yggdrasil.Registry, as: Reg

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
    transformer_alias = Keyword.get(options, :name)

    quote do
      @behaviour Yggdrasil.Transformer
      alias Yggdrasil.Registry, as: Reg

      use Task, restart: :transient

      @doc false
      def start_link(_) do
        Task.start_link(__MODULE__, :register, [])
      end

      @doc false
      def register do
        name = unquote(transformer_alias)
        with :ok <- Reg.register_transformer(name, __MODULE__) do
          :ok
        else
          :error ->
            exit(:error)
        end
      end

      @doc false
      def decode(_channel, message) do
        {:ok, message}
      end

      @doc false
      def encode(_channel, message) do
        {:ok, message}
      end

      defoverridable [decode: 2, encode: 2]
    end
  end

  @doc """
  Generic `message` decoder for a `channel`.
  """
  @spec decode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}
  def decode(channel, message)

  def decode(%Channel{transformer: name} = channel, message) do
    with {:ok, module} <- Reg.get_transformer_module(name) do
      module.decode(channel, message)
    end
  end

  @doc """
  Generic `message` encoder for a `channel`.
  """
  @spec encode(Channel.t(), term()) :: {:ok, term()} | {:error, term()}
  def encode(channel, message)

  def encode(%Channel{transformer: name} = channel, message) do
    with {:ok, module} <- Reg.get_transformer_module(name) do
      module.encode(channel, message)
    end
  end
end
