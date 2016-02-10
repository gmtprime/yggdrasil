defmodule Yggdrasil.Broker.Redis do
  use Yggdrasil.Broker

  def subscribe(channel, callback) do
    {:ok, conn} = Exredis.Sub.start_link
    conn |> Exredis.Sub.psubscribe(channel, callback)
    {:ok, conn}
  end

  def unsubscribe(conn) do
    Exredis.Sub.stop conn
  end

  def handle_message(_conn, {:subscribed, _id, _pid}), do:
    :subscribed
  def handle_message(_conn, {:pmessage, _id, _channel, message, _pid}), do:
    {:message, message}
  def handle_message(_conn, {:message, _id, message, _pid}), do:
    {:message, message}
  def handle_message(_conn, _ignored), do:
    :whatever
end
