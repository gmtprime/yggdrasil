defmodule Yggdrasil.Test.TestGenericBroker do
  use Yggdrasil.Broker.GenericBroker,
      broker: Yggdrasil.Test.TestBroker,
      interval: 200 

  def decode(message) when is_atom(message), do:
    {:message, Atom.to_string(message)}
end
