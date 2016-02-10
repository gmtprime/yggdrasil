defmodule Yggdrasil.Test.TestSubscriber do
  use Yggdrasil.Subscriber.Base, broker: Yggdrasil.Broker.Redis
  alias Yggdrasil.Util.Forwarder, as: Forwarder

  def init(nil), do:
    {:ok, nil}
  def init(forwarder) do
    Forwarder.notify forwarder, {:started, self()}
    {:ok, forwarder}
  end

  def handle_message(message, forwarder) do
    Forwarder.notify forwarder, {:received, message}
    :ok
  end

  def terminate(reason, forwarder), do:
    Forwarder.notify forwarder, {:stopped, reason, self()} 
end
