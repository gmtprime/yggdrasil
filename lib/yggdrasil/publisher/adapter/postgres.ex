defmodule Yggdrasil.Publisher.Adapter.Postgres do
  @moduledoc """
  Yggdrasil publisher adapter for Postgres. The name of the channel must be a
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
  alias Yggdrasil.Subscriber.Adapter.Postgres

  defstruct [:conn, :namespace]
  alias __MODULE__, as: State

  #############################################################################
  # Client API.

  @doc """
  Starts a Postgres publisher with a `namespace`. Additianally you can add
  `GenServer` `options`.
  """
  @spec start_link(term()) :: GenServer.on_start()
  @spec start_link(term(), GenServer.options()) :: GenServer.on_start()
  def start_link(namespace, options \\ [])

  def start_link(namespace, options) do
    Connection.start_link(__MODULE__, namespace, options)
  end

  @doc """
  Stops a Postgres `publisher`.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(publisher)

  def stop(publisher) do
    GenServer.stop(publisher)
  end

  @doc """
  Publishes a `message` in a `channel` using a `publisher` and optional and
  unused `options`.
  """
  @spec publish(GenServer.server(), Channel.t(), term()) ::
    :ok | {:error, term()}
  @spec publish(GenServer.server(), Channel.t(), term(), Keyword.t()) ::
    :ok | {:error, term()}
  def publish(publisher, channel, message, options \\ [])

  def publish(publisher, %Channel{} = channel, message, _options) do
    Connection.call(publisher, {:publish, channel, message})
  end

  #############################################################################
  # GenServer callback.

  @doc false
  def init(namespace) do
    Process.flag(:trap_exit, true)
    state = %State{namespace: namespace}
    {:connect, :init, state}
  end

  @doc false
  def connect(_info, %State{namespace: namespace} = state) do
    options = Postgres.postgres_options(%Channel{namespace: namespace})
    {:ok, conn} = Postgrex.start_link(options)
    {:ok, %State{state | conn: conn}}
  end

  @doc false
  def disconnect(_info, %State{conn: nil} = state) do
    {:backoff, 5000, state}
  end
  def disconnect(info, %State{conn: conn} = state) do
    GenServer.stop(conn)
    disconnect(info, %State{state | conn: nil})
  end

  @doc false
  def handle_call(
    {:publish, _, _},
    _from,
    %State{conn: nil} = state
  ) do
    {:reply, {:error, "Disconnected"}, state}
  end
  def handle_call(
    {:publish, %Channel{name: name, transformer: encoder} = channel, message},
    _from,
    %State{conn: conn} = state
  ) do
    result =
      with {:ok, encoded} <- encoder.encode(channel, message),
           {:ok, _} <- Postgrex.query(conn, "NOTIFY #{name}, '#{encoded}'", []),
           do: :ok
    {:reply, result, state}
  end
  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @doc false
  def handle_info({:DOWN, _, :process, _pid, _reason}, %State{} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :down, new_state}
  end
  def handle_info({:EXIT, _, _}, %State{} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :exit, new_state}
  end

  @doc false
  def terminate(reason, %State{conn: nil} = state) do
    terminated(reason, state)
  end
  def terminate(reason, %State{conn: conn} = state) do
    GenServer.stop(conn)
    terminate(reason, %State{state | conn: nil})
  end

  defp terminated(reason, %State{} = _state) do
    metadata = [error: reason]
    Logger.debug(fn ->
      "Terminated Postgres connection #{inspect metadata}"
    end)
    :ok
  end
end
