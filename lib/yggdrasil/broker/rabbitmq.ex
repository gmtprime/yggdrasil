defmodule Yggdrasil.Broker.RabbitMQ do
  use Yggdrasil.Broker

  def subscribe({exchange, routing_key}, _callback) do
    config = Yggdrasil.Broker.RabbitMQConfig.fetch_env

    {:ok, conn} = AMQP.Connection.open(username: config.username,
                                       password: config.password,
                                       host: config.host, port: config.port,
                                       virtual_host: config.virtual_host) 
    {:ok, chan} = AMQP.Channel.open conn
    {:ok, %{queue: queue}} = AMQP.Queue.declare(chan, "", exclusive: true)
    AMQP.Queue.bind(chan, queue, exchange, routing_key: routing_key)
    {:ok, _consumer_tag} = AMQP.Basic.consume chan, queue
    {:ok, %{connection: conn, channel: chan}}
  end

  def unsubscribe(%{connection: conn, channel: chan}) do
    AMQP.Channel.close chan
    AMQP.Connection.close conn
  end

  def handle_message(_conn, {:basic_consume_ok, %{consumer_tag: _tag}}), do:
    :subscribed
  def handle_message(_conn, {:basic_cancel, _}), do:
    {:stop, :shutdown}
  def handle_message(%{channel: chan},
                     {:basic_deliver, message,
                      %{delivery_tag: tag, redelivered: redelivered}}) do
    try do
      spawn fn -> AMQP.Basic.ack(chan, tag) end
      {:message, message}
    rescue
      _exception ->
        spawn fn -> AMQP.Basic.reject(chan, tag, requeue: not redelivered) end
        {:stop, :shutdown}
    end
  end
  def handle_message(_conn, _ignored), do:
    :whatever
end
