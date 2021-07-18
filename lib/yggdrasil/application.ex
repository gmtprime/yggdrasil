defmodule Yggdrasil.Application do
  @moduledoc false
  use Application

  alias Yggdrasil.Adapter.Bridge.Generator, as: BridgeGen
  alias Yggdrasil.Publisher.Generator, as: PublisherGen
  alias Yggdrasil.Subscriber.Generator, as: SubscriberGen

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, [name: Yggdrasil.PubSub]},
      %{
        id: Manager.PG,
        start: {:pg, :start_link, [Yggdrasil.Subscriber.Manager]}
      },
      {PublisherGen, [name: Yggdrasil.Publisher.Generator]},
      {SubscriberGen, [name: Yggdrasil.Subscriber.Generator]},
      Yggdrasil.Registry,
      {Yggdrasil.Backend.Default, []},
      {Yggdrasil.Transformer.Default, []},
      {Yggdrasil.Transformer.Json, []},
      {Yggdrasil.Adapter.Elixir, []},
      {Yggdrasil.Adapter.Bridge, []},
      {BridgeGen, [name: BridgeGen]}
    ]

    options = [
      strategy: :rest_for_one,
      name: Yggdrasil.Supervisor
    ]

    Supervisor.start_link(children, options)
  rescue
    reason ->
      {:error, reason}
  end
end
