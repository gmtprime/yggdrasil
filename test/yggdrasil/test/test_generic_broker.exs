defmodule Yggdrasil.Test.TestGenericBroker do
  use Yggdrasil.Broker.GenericBroker,
      broker: Yggdrasil.Test.TestBroker,
      interval: 200,
      cache: :test_cache

  def decode(_channel, message) when is_atom(message), do:
    {:message, Atom.to_string(message)}
end
