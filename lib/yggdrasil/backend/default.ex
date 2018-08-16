defmodule Yggdrasil.Backend.Default do
  @moduledoc """
  Distributor backend to subscribe, unsubscribe and publish messages. Uses
  `Phoenix.PubSub` for message distribution.

  This module contains helper functions used by the adapters to broadcast their
  messages. The possible messages are:

    - `{:Y_CONNECTED, Channel.()}`: When a subscriber connects to a channel
    successfully. See `connected/2` function.
    - `{:Y_DISCONNECTED, Channel.()}`; When a subscriber disconnects from
    a channel successfully. See `disconnected/2` function.
    - `{:Y_EVENT, Channel.t(), message()} when message: term()`: When a
    subscriber gets a new messages from the adapter. See `publish/2` function.
  """
  use Yggdrasil.Transformer, name: :default
end
