defmodule Yggdrasil.Test.TestBroker do
  use GenServer
  use Yggdrasil.Broker

  ###################
  # Client functions.

  def start_link() do
    GenServer.start_link __MODULE__, nil, []
  end

  def publish(broker, channel, message), do:
    GenServer.cast broker, {:publish, channel, message}

  def stop(broker), do:
    GenServer.cast broker, :stop

  ###################
  # Client callbacks.

  @timeout 1000

  def subscribe(:channel_timeout = channel, callback) do
    {:ok, conn} = __MODULE__.start_link
    conn |> GenServer.cast({:subscribe, channel, callback})
    {:ok, conn, 200}
  end
 
  def subscribe(:channel = channel, callback) do
    {:ok, conn} = __MODULE__.start_link
    conn |> GenServer.cast({:subscribe, channel, callback})
    {:ok, conn}
  end


  def unsubscribe(conn) do
    __MODULE__.stop conn
  end


  def handle_message(_conn, :subscribed), do:
    :subscribed
  def handle_message(_conn, {:message, message}), do:
    {:message, message}
  def handle_message(_conn, _ignored), do:
    :whatever

  ###################
  # Server callbacks.

  def init(_) do
    {:ok, %{}}
  end

  def handle_cast(:stop, state), do:
    {:stop, :normal, state}
  def handle_cast({:subscribe, channel, callback}, state) do
    new_state = Map.put state, channel, callback
    callback.(:subscribed)
    {:noreply, new_state}
  end
  def handle_cast({:publish, channel, message}, state) do
    case Map.fetch state, channel do
      :error ->
        :ok
      {:ok, callback} ->
        callback.({:message, message})
    end
    {:noreply, state}
  end
  def handle_cast(_any, state), do:
    {:noreply, state}
end
