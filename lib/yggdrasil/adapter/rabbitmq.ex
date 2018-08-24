defmodule Yggdrasil.Adapter.RabbitMQ do
  @moduledoc """
  Yggdrasil adapter for RabbitMQ. The name of the channel must be a tuple with
  two binaries for exchange and routing key in that order e.g:

  Subscription to channel:

  ```
  iex(2)> channel = %Yggdrasil.Channel{
  iex(2)>   name: {"amq.topic", "my_routing"},
  iex(2)>   adapter: :rabbitmq
  iex(2)> }
  iex(3)> Yggdrasil.subscribe(channel)
  :ok
  iex(4)> flush()
  {:Y_CONNECTED, %Yggdrasil.Channel{name: {"amq.topic", "routing"}, (...)}}
  ```

  Publishing message:

  ```
  iex(5)> Yggdrasil.publish(channel, "foo")
  :ok
  ```

  Subscriber receiving message:

  ```
  iex(6)> flush()
  {:Y_EVENT, %Yggdrasil.Channel{name: {"amq.topic", "routing"}, (...)}, "foo"}
  ```

  The subscriber can also unsubscribe from the channel:

  ```
  iex(7)> Yggdrasil.unsubscribe(channel)
  :ok
  iex(8)> flush()
  {:Y_DISCONNECTED, %Yggdrasil.Channel{name: {"amq.topic", "routing"}, (...)}}
  ```
  """
  use Yggdrasil.Adapter, name: :rabbitmq
end
