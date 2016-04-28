defmodule Yggdrasil.Broker.Redis do
  use Yggdrasil.Broker

  def subscribe(channel, callback) do
    {:ok, conn} = Exredis.Sub.start_link
    conn |> Exredis.Sub.psubscribe(channel, callback)
    {:ok, conn}
  end

  def unsubscribe(conn, _channel) do
    Exredis.Sub.stop conn
  end

  def handle_message(_conn, _, {:subscribed, _id, _pid}), do:
    :subscribed
  def handle_message(_conn, _, {:pmessage, _id, _channel, message, _pid}), do:
    {:message, message}
  def handle_message(_conn, _, {:message, _id, message, _pid}), do:
    {:message, message}
  def handle_message(_conn, _, {:eredis_disconnect, _pid}), do:
    {:stop, :shutdown}
  def handle_message(_conn, _, {:eredis_reconnect_attempt, _pid}), do:
    {:stop, :shutdown}
  def handle_message(_conn, _, _ignored), do:
    :whatever
end
