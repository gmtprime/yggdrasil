defmodule Yggdrasil.Broker do
  @doc false
  defmacro __using__(_) do
    quote location: :keep do
      @behaviour Yggdrasil.Broker

      @doc false
      def subscribe(_channel, _callback) do
        {:ok, nil}
      end

      @doc false
      def unsubscribe(_conn, _channel) do
        :ok
      end

      @doc false
      def handle_message(_conn, _channel, _message) do
        {:message, nil}
      end
      
      defoverridable [ subscribe: 2, unsubscribe: 2, handle_message: 3]
    end
  end

  @doc """
  Subscribes to the `channel` and bind the `callback` to handle the messages.
  """
  @callback subscribe(channel :: any, callback :: term) ::
    {:ok, handle :: any} |
    {:ok, handle :: any, timeout :: integer} |
    {:error, reason :: term}

  @doc """
  Unsubscribes from using a `handle` to the `channel`.
  """
  @callback unsubscribe(handle :: any, channel :: any) :: :ok | :error

  @doc """
  Handle messages from the broker. Accepted outputs:

  > `:subscribed` When the process is subscribed to the broker.
  > `{:message, message}` When the process receives a message from the broker.
  > `{:stop, reason}` When the process should be shutdown.
  """
  @callback handle_message(conn :: any, channel :: any, message :: any) ::
    :subscribed |
    {:message, message :: term} |
    {:stop, reason :: term} |
    any
end
