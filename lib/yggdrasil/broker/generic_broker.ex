defmodule Yggdrasil.Broker.GenericBroker do
  defmacro __using__(options \\ []) do
    broker = Keyword.get options, :broker, Yggdrasil.Broker.Redis
    interval = Keyword.get options, :interval, nil
    return = if interval != nil do
               quote do: {:ok, conn, unquote(interval)}
             else
               quote do: {:ok, conn}
             end
    quote do
      def subscribe(channel, callback) do
        broker = unquote(broker)
        {:ok, conn} = broker.subscribe channel, callback
        unquote(return)
      end

      def unsubscribe(conn) do
        broker = unquote(broker)
        broker.unsubscribe conn
      end

      def handle_message(conn, message) do
        broker = unquote(broker)
        case broker.handle_message conn, message do
          {:message, message} -> __MODULE__.decode(message)
          other -> other
        end
      end

      @spec decode(message :: term) :: {:message, message :: term} | term
      def decode(message), do:
        {:message, message}

      defoverridable [ decode: 1]
    end
  end
end
