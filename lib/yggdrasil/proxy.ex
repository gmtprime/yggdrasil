defmodule Yggdrasil.Proxy do
  @moduledoc """
  Redirects messages from a broker to a subscriber.
  """
  use GenEvent

  defmodule Data do
    defstruct data: nil, channel: nil, broker: nil
    @type t :: %__MODULE__{data: term, channel: term, broker: atom}
  end

  #############
  # Client API.

  @doc """
  Starts a proxy.
  """
  def start_link(opts \\ []) do
    GenEvent.start_link opts
  end

  @doc """
  Stops the `proxy`.
  """
  def stop(proxy) do
    GenEvent.stop proxy
  end

  @doc """
  Subscribes to a `channel` from a `broker`, using a `callback`/1 to handle
  the message.
  """
  def subscribe(manager, broker, channel, callback \\ nil) do
    ref = make_ref()
    callback = case callback do
      nil ->
        pid = self()
        &(send pid, &1)
      _ ->
        callback
    end
    args = [ref, broker, channel, callback]
    case GenEvent.add_mon_handler manager, {Yggdrasil.Proxy, ref}, args do
      :ok ->
        {:ok, %{broker: broker, channel: channel, ref: ref}}
      error ->
        error
    end
  end


  @doc """
  Unsubscribe from a channel using the `id` of the event handler.
  """
  def unsubscribe(manager, %{broker: broker, channel: channel, ref: ref}) do
    message = %{broker: broker, channel: channel, unsubscribe: ref}
    GenEvent.notify manager, message
  end


  @doc """
  Publishes `data` from a `broker` to the subscribers of a `channel`.
  """
  def publish(manager, broker, channel, data) do
    event = %{broker: broker,
              channel: channel,
              data: data}
    GenEvent.notify manager, event
  end

  ##########################
  # Event handler callbacks.

  @doc """
  Initializes the proxy. Receives the `callback` to execute when the `broker`
  receives a message in a `channel`.
  """
  def init([ref, broker, channel, callback]) do
    {:ok, %{ref: ref, broker: broker, channel: channel, callback: callback}}
  end


  @doc """
  Handles an event.
  """
  def handle_event(%{broker: broker, channel: channel, unsubscribe: ref},
                   %{broker: broker, channel: channel, ref: ref}), do:
    :remove_handler
  def handle_event(%{broker: broker, channel: channel, data: data},
                   %{broker: broker, channel: channel} = state) do 
    data = %Data{broker: broker, data: data, channel: channel}  
    spawn fn -> state.callback.(data) end
    {:ok, state}
  end
  def handle_event(_other, state), do:
    {:ok, state}
end
