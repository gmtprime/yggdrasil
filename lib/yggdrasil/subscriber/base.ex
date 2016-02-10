defmodule Yggdrasil.Subscriber.Base do
  use GenServer
  alias Yggdrasil.Feed, as: Feed

  @doc """
  Initializes the subscriber state.
  """
  @callback init(args :: term) ::
    {:ok, state :: term} |
    {:error, reason :: term}

  @doc """
  Updates the subscriber state.
  """
  @callback update_state(old_state :: term, new_state :: term) :: state :: term

  @doc """
  Handles the messages received from the broker. This functions is called in a
  separated process.
  """
  @callback handle_message(message :: term, state :: term) :: :ok | :error

  @doc """
  Handles the termination of the subscriber server.
  """
  @callback terminate(reason :: term, state :: term) :: term

  defmacro __using__(options) do
    broker = Keyword.pop(options, :broker, Yggdrasil.Broker.Redis) |> elem(0)
    quote do
      @behaviour Yggdrasil.Subscriber.Base

      ####################
      # Default functions.

      @doc """
      Starts a subscriber.

      Args:
        `feed` - Feed from where it'll receive the messages.
        `args` - Internal state. State of the subscriber.
        `options` - Options (GenServer options).

      Returns:
        GenServer output.
      """
      @spec start_link(feed :: pid | atom | {atom | node}, args :: term,
                       options :: term) ::
        {:ok, pid} |
        :ignore |
        {:error, {:already_started, pid} | term}
      def start_link(feed, args \\ nil, options \\ []) do
        broker = unquote(broker)
        state = %{module: __MODULE__, broker: broker, feed: feed,
                  channels: %{}, internal_state: args}
        GenServer.start_link Yggdrasil.Subscriber.Base, state, options
      end

      @doc """
      Updates the state of the subscriber.

      Args:
        `server` - Subscriber pid.
        `state` - New state.
      """
      @spec register(server :: pid | atom | {atom, node}, state :: term) ::
        term
      def register(server, state), do:
        GenServer.call server, {:update, state}

      @doc """
      Subscribes to a channel.

      Args:
        `server` - Subscriber pid.
        `channel` - Channel name
      """
      @spec subscribe(server :: pid | atom | {atom, node}, channel :: term) ::
        term
      def subscribe(server, channel), do:
        GenServer.call server, {:subscribe, channel}

      @doc """
      Unsubscribes from a channel.

      Args:
        `server` - Subscriber pid.
        `channel` - Channel name.
      """
      def unsubscribe(server, channel), do:
        GenServer.call server, {:unsubscribe, channel}

      @doc """
      Stops the subscriber.
      
      Args:
        `server` - Subscriber pid.
        `reason` - Reason to stop (default = `:normal`)
      """
      def stop(server, reason \\ :normal), do:
        GenServer.call server, {:stop, reason}

      ####################
      # Default callbacks.

      def init(state), do:
        {:ok, state}

      def update_state(_old_state, new_state), do:
        new_state

      def handle_message(_message, state), do:
        :ok

      def terminate(_reason, _state), do:
        :ok 

      defoverridable [ init: 1, update_state: 2, handle_message: 2,
                       terminate: 2] 
    end
  end

  @feed Yggdrasil.Feed

  ######################
  # GenServer callbacks.

  def init(state) do
    case state.module.init(state.internal_state) do
      {:ok, internal_state} ->
        {:ok, %{state | internal_state: internal_state}}
      {:error, reason} ->
        {:stop, reason}
      _ ->
        {:stop, :unknown_error}
    end
  end


  def handle_call({:stop, reason}, _from, state), do:
    {:stop, reason, :ok, state}

  def handle_call({:update, internal_state}, _from, state) do
    internal_state = state.module.update_state(state.internal_state,
                                               internal_state)
    {:reply, :ok, %{state | internal_state: internal_state}}
  end

  def handle_call({:subscribe, channel}, _from, state) do
    case Map.fetch state.channels, channel do
      :error -> 
        {:ok, handle} = Feed.subscribe state.feed, state.broker, channel
        channels = Map.put_new state.channels, channel, handle
        {:reply, :ok, %{state | channels: channels}}
      _ ->
        {:reply, {:error, :already_subscribed}, state}
    end
  end

  def handle_call({:unsubscribe, channel}, _from, state) do
    case Map.pop state.channels, channel, nil do
      {nil, _} ->
        {:reply, {:error, :already_unsubscribed}, state}
      {handle, channels} ->
        Feed.unsubscribe state.feed, handle 
        {:reply, :ok, %{state | channels: channels}}
    end 
  end

  def handle_call(_message, _from, state), do:
    {:noreply, state}


  def handle_info({:gen_event_EXIT, {_, _}, :normal}, state), do:
    {:noreply, state}

  def handle_info({:gen_event_EXIT, {_, _}, reason}, state), do:
    {:stop, reason, state}

  def handle_info(message, state) do
    spawn fn ->
      state.module.handle_message(message, state.internal_state)
    end
    {:noreply, state}
  end


  def terminate(reason, state), do:
    state.module.terminate(reason, state.internal_state)
end
