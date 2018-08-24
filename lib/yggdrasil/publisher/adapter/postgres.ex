defmodule Yggdrasil.Publisher.Adapter.Postgres do
  @moduledoc """
  Yggdrasil publisher adapter for Postgres. The name of the channel must be a
  binary e.g:

  Subscription to channel:

  ```
  iex(2)> channel = %Yggdrasil.Channel{name: "pg_channel", adapter: :postgres}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: "pg_channel", (...)}}
  ```

  Publishing message:

  ```
  iex(5)> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  Subscriber receiving message:

  ```
  iex(6)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: "pg_channel", (...)}, "foo"}
  ```

  The subscriber can also unsubscribe from the channel:

  ```
  iex(7)> Yggdrasil.unsubscribe(channel)
  :ok
  iex(8)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{name: "pg_channel", (...)}}
  ```
  """
  use Yggdrasil.Publisher.Adapter
  use Connection

  require Logger

  alias Yggdrasil.Channel
  alias Yggdrasil.Transformer
  alias Yggdrasil.Subscriber.Adapter.Postgres

  defstruct [:conn, :namespace]
  alias __MODULE__, as: State

  ############
  # Client API

  @doc """
  Starts a Postgres publisher with a `namespace`. Additianally you can add
  `GenServer` `options`.
  """
  @spec start_link(term()) :: GenServer.on_start()
  @spec start_link(term(), GenServer.options()) :: GenServer.on_start()
  @impl true
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
  @impl true
  def publish(publisher, channel, message, options \\ [])

  def publish(publisher, %Channel{} = channel, message, _options) do
    Connection.call(publisher, {:publish, channel, message})
  end

  ####################
  # GenServer callback

  @impl true
  def init(namespace) do
    Process.flag(:trap_exit, true)
    state = %State{namespace: namespace}
    {:connect, :init, state}
  end

  @impl true
  def connect(_info, %State{namespace: namespace} = state) do
    options = Postgres.postgres_options(%Channel{namespace: namespace})
    {:ok, conn} = Postgrex.start_link(options)
    {:ok, %State{state | conn: conn}}
  end

  @impl true
  def disconnect(_info, %State{conn: nil} = state) do
    {:backoff, 5000, state}
  end
  def disconnect(info, %State{conn: conn} = state) do
    GenServer.stop(conn)
    disconnect(info, %State{state | conn: nil})
  end

  @impl true
  def handle_call(
    {:publish, _, _},
    _from,
    %State{conn: nil} = state
  ) do
    {:reply, {:error, "Disconnected"}, state}
  end
  def handle_call(
    {:publish, %Channel{name: name} = channel, message},
    _from,
    %State{conn: conn} = state
  ) do
    result =
      with {:ok, encoded} <- Transformer.encode(channel, message),
           {:ok, _} <- Postgrex.query(conn, "NOTIFY #{name}, '#{encoded}'", []),
           do: :ok
    {:reply, result, state}
  end
  def handle_call(_msg, _from, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _, :process, _pid, _reason}, %State{} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :down, new_state}
  end
  def handle_info({:EXIT, _, _}, %State{} = state) do
    new_state = %State{state | conn: nil}
    {:disconnect, :exit, new_state}
  end

  @impl true
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
