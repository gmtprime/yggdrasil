defmodule Yggdrasil.Publisher.Adapter.Elixir do
  @moduledoc """
  Yggdrasil publisher adapter for Elixir. The name of the channel can be any
  arbitrary term e.g:

  Subscription to channel:

  ```
  iex(2)> channel = %Yggdrasil.Channel{name: "elixir_channel"}
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: "elixir_channel", (...)}}
  ```

  Publishing message:

  ```
  iex(5)> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  Subscriber receiving message:

  ```
  iex(6)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: "elixir_channel", (...)}, "foo"}
  ```

  The subscriber can also unsubscribe from the channel:

  ```
  iex(7)> Yggdrasil.unsubscribe(channel)
  :ok
  iex(8)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{name: "elixir_channel", (...)}}
  ```
  """
  use GenServer

  alias Yggdrasil.Channel
  alias Yggdrasil.Distributor.Backend

  ############
  # Client API

  @doc """
  Starts an elixir publisher with a `namespace`. Additianally you can add
  `GenServer` `options`.
  """
  @spec start_link(term()) :: GenServer.on_start()
  @spec start_link(term(), GenServer.options()) :: GenServer.on_start()
  def start_link(namespace, options \\ [])

  def start_link(_, options) do
    GenServer.start_link(__MODULE__, nil, options)
  end

  @doc """
  Stops an elixir `publisher`.
  """
  @spec stop(GenServer.server()) :: :ok
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
    GenServer.call(publisher, {:publish, channel, message})
  end

  ####################
  # GenServer callback

  @doc false
  def init(_) do
    {:ok, nil}
  end

  @doc false
  def handle_call(
    {:publish, %Channel{transformer: encoder, name: name} = channel, message},
    _from,
    _state
  ) do
    stream = %Channel{
      channel | name: {:elixir, name},
                adapter: Yggdrasil.Subscriber.Adapter.Elixir
    }
    result =
      with {:ok, encoded} <- encoder.encode(stream, message) do
        Backend.publish(stream, encoded)
      end
    {:reply, result, nil}
  end
  def handle_call(_msg, _from, _state) do
    {:noreply, nil}
  end
end
