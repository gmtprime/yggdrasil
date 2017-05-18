defmodule Yggdrasil.Subscriber.Adapter.Postgres do
  @moduledoc """
  Yggdrasil subscriber adapter for Postgres. The name of the channel must be a
  binary e.g:

  Subscription to channel:

  ```elixir
  iex(1)> alias Yggdrasil.Channel
  iex(2)> sub_channel = %Channel{
  ...(2)>   name: "postgres_channel",
  ...(2)>   adapter: Yggdrasil.Subscriber.Adapter.Postgres
  ...(2)> }
  iex(3)> Yggdrasil.subscribe(sub_channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Channel{name: "postgres_channel", (...)}}
  ```

  Publishing message:

  ```elixir
  iex(5)> pub_channel = %Channel{
  ...(5)>   name: "postgres_channel",
  ...(5)>   adapter: Yggdrasil.Publisher.Adapter.Postgres
  ...(5)> }
  iex(6)> Yggdrasil.publish(pub_channel, "message")
  :ok
  ```

  Subscriber receiving message:

  ```elixir
  iex(7)> flush()
  {:Y_EVENT, %Channel{name: "postgres_channel", (...)}, "message"}
  ```

  Instead of having `sub_channel` and `pub_channel`, the hibrid channel can be
  used. For the previous example we can do the following:

  ```elixir
  iex(1)> alias Yggdrasil.Channel
  iex(2)> channel = %Channel{name: "postgres_channel", adapter: :postgres}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Channel{name: "postgres_channel", (...)}}
  iex(5)> Yggdrasil.publish(channel, "message")
  :ok
  iex(6)> flush()
  {:Y_EVENT, %Channel{name: "postgres_channel", (...)}, "message"} 
  ```
  """
  use Connection

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Publisher
  alias Yggdrasil.Distributor.Backend

  defstruct [:publisher, :channel, :conn, :ref]
  alias __MODULE__, as: State

  #############################################################################
  # Client API.

  @doc """
  Starts a Postgres distributor adapter in a `channel` with some distributor
  `publisher` and optionally `GenServer` `options`.
  """
  def start_link(%Channel{} = channel, publisher, options \\ []) do
    state = %State{publisher: publisher, channel: channel}
    Connection.start_link(__MODULE__, state, options)
  end

  @doc """
  Stops the Postgres adapter with its `pid`.
  """
  def stop(pid) do
    GenServer.stop(pid)
  end

  #############################################################################
  # Connection callbacks.

  @doc false
  def init(%State{} = state) do
    Process.flag(:trap_exit, true)
    {:connect, :init, state}
  end

  @doc false
  def connect(
    _info,
    %State{channel: %Channel{name: name} = channel} = state
  ) do
    options = postgres_options(channel)
    {:ok, conn} = Postgrex.Notifications.start_link(options)
    try do
      Postgrex.Notifications.listen(conn, name)
    catch
      _, reason ->
        backoff(reason, state)
    else
      {:ok, ref} ->
        connected(conn, ref, state)
      error ->
        backoff(error, state)
    end
  end

  ##
  # Backoff.
  defp backoff(error, %State{channel: %Channel{name: name}} = state) do
    metadata = [channel: name, error: error]
    Logger.error(fn ->
      "Cannot connect to Postgres #{inspect metadata}"
    end)
    {:backoff, 5000, state}
  end

  ##
  # Connected.
  defp connected(
    conn,
    ref,
    %State{channel: %Channel{name: name} = channel} = state
  ) do
    Process.monitor(conn)
    metadata = [channel: name]
    Logger.debug(fn ->
      "Connected to Postgres #{inspect metadata}"
    end)
    new_state = %State{state | conn: conn, ref: ref}
    Backend.connected(channel)
    {:ok, new_state}
  end

  @doc false
  def disconnect(_info, %State{ref: nil, conn: nil} = state) do
    disconnected(state)
  end
  def disconnect(info, %State{conn: conn, ref: ref} = state) do
    Postgrex.Notifications.unlisten(conn, ref)
    GenServer.stop(conn)
    disconnect(info, %State{state | conn: nil, ref: nil})
  end

  ##
  # Disconnected.
  defp disconnected(%State{channel: %Channel{name: name}} = state) do
    metadata = [channel: name]
    Logger.debug(fn ->
      "Disconnected from Postgres #{inspect metadata}"
    end)
    {:backoff, 5000, state}
  end

  @doc false
  def handle_info(
    {:notification, _, _, channel, message},
    %State{publisher: publisher} = state
  ) do
    Publisher.notify(publisher, channel, message)
    {:noreply, state}
  end
  def handle_info({:DOWN, _, :process, _, _}, %State{} = state) do
    new_state = %State{state | conn: nil, ref: nil}
    {:disconnect, :down, new_state}
  end
  def handle_info({:EXIT, _, _}, %State{} = state) do
    new_state = %State{state | conn: nil, ref: nil}
    {:disconnect, :exit, new_state}
  end
  def handle_info(_, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def terminate(reason, %State{conn: nil, ref: nil} = state) do
    terminated(reason, state)
  end
  def terminate(reason, %State{conn: conn, ref: ref} = state) do
    Postgrex.Notifications.unlisten(conn, ref)
    GenServer.stop(conn)
    terminate(reason, %State{state | conn: nil, ref: nil})
  end

  ##
  # Terminated.
  defp terminated(reason, %State{channel: %Channel{name: name}}) do
    metadata = [channel: name, reason: reason]
    Logger.debug(fn ->
      "Terminated Postgres connection #{inspect metadata}"
    end)
    :ok
  end

  #############################################################################
  # Helpers.

  @doc false
  def postgres_options(%Channel{namespace: Yggdrasil}) do
    Application.get_env(:yggdrasil, :postgres, [])
  end
  def postgres_options(%Channel{namespace: namespace}) do
    default = [postgres: []]
    result = Application.get_env(:yggdrasil, namespace, default)
    Keyword.get(result, :postgres, [])
  end
end
