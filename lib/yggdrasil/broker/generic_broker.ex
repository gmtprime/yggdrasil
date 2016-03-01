defmodule Yggdrasil.Broker.GenericBroker do
  defmacro __using__(options \\ []) do
    broker = Keyword.get options, :broker, Yggdrasil.Broker.Redis
    interval = Keyword.get options, :interval, nil
    table = Keyword.get options, :cache, nil
    quote do
      defp _get_return(conn, nil), do:
        {:ok, conn}
      defp _get_return(conn, interval) when is_integer(interval), do:
        {:ok, conn, interval}
      defp _get_return(conn, _interval), do:
        {:ok, conn}

      def subscribe(channel, callback) do
        broker = unquote(broker)
        {:ok, conn} = broker.subscribe channel, callback
        __MODULE__.init_cache(channel, unquote(table))
        _get_return(conn, unquote(interval))
      end

      def unsubscribe(conn, channel) do
        broker = unquote(broker)
        broker.unsubscribe conn, channel
      end

      def handle_message(conn, channel, message) do
        broker = unquote(broker)
        case broker.handle_message conn, channel, message do
          {:message, message} ->
            decoded = __MODULE__.decode(channel, message)
            __MODULE__.store_in_cache(unquote(table), channel, decoded)
            decoded
          other -> other
        end
      end

      @spec init_cache(channel :: any, table :: any) :: :ok
      def init_cache(_channel, nil), do: :ok

      def init_cache(_channel, table) when is_atom(table) do
        case :ets.info(table) do
          :undefined ->
            :ets.new(table, [:set, :named_table, :public,
                             read_concurrency: true, write_concurrency: true])
            :ok
          _ ->
            :ok
        end
      end

      def init_cache(_channel, _table), do: :ok

      @spec decode(channel :: any, message :: term)
        :: {:message, message :: term} | term
      def decode(_channel, message), do:
        {:message, message}

      @spec store_in_cache(table :: any, channel :: any, message :: any) :: :ok
      def store_in_cache(nil, _channel, _message), do: :ok

      def store_in_cache(table, channel, {:message, message})
        when is_atom(table) do
        :ets.insert(table, {channel, message})
        :ok
      end

      def store_in_cache(table, channel, message) when is_atom(message) do
        :ets.insert(table, {channel, message})
        :ok
      end

      def store_in_cache(_table, _channel, _message), do: :ok

      defoverridable [ init_cache: 2, decode: 2, store_in_cache: 3]
    end
  end
end
