defmodule Yggdrasil.Broker.Postgres do
  use Yggdrasil.Broker

  def subscribe({repo, channel}, _callback) when is_atom(repo) do
    config = Application.get_env(:postgrex, repo)
    _subscribe(channel, config)
  end

  def subscribe(channel, _callback) when is_binary(channel) do
    config = Application.get_env(:postgrex, Yggdrasil.Repo)
    _subscribe(channel, config)
  end

  defp _subscribe(channel, config) do
    {:ok, conn} = Postgrex.Notifications.start_link(config)
    {:ok, ref} = Postgrex.Notifications.listen(conn, channel)
    _notify(channel, ref, config)
    {:ok, %{connection: conn, ref: ref}}
  end

  defp _notify(channel, message, config) when is_binary(message) do
    {:ok, conn} = Postgrex.start_link(config)
    Postgrex.query(conn, "NOTIFY #{channel}, '#{message}'", [])
    GenServer.stop(conn)
  end

  defp _notify(channel, message, config), do:
    _notify(channel, inspect(message), config)

  def unsubscribe(%{connection: conn, ref: ref}, _channel) do
    Postgrex.Notifications.unlisten(conn, ref)
    GenServer.stop(conn)
  end

  def handle_message(_, _, {:notification, _, ref, _, message}), do:
    _handle_message(message, inspect(ref))
  def handle_message(_, _, _), do:
    :whatever

  defp _handle_message(ref, ref), do:
    :subscribed
  defp _handle_message(message, _), do:
    {:message, message}
end
