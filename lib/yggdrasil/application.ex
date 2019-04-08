defmodule Yggdrasil.Application do
  @moduledoc false
  use Application

  alias Yggdrasil.Adapter.Bridge.Generator, as: BridgeGen
  alias Yggdrasil.Publisher.Generator, as: PublisherGen
  alias Yggdrasil.Registry
  alias Yggdrasil.Settings
  alias Yggdrasil.Subscriber.Generator, as: SubscriberGen

  @impl true
  def start(_type, _args) do
    children = [
      pubsub_adapter(),
      {PublisherGen, [name: PublisherGen]},
      {SubscriberGen, [name: SubscriberGen]},
      {Registry, [name: Registry]},
      {Yggdrasil.Backend.Default, []},
      {Yggdrasil.Transformer.Default, []},
      {Yggdrasil.Transformer.Json, []},
      {Yggdrasil.Adapter.Elixir, []},
      {Yggdrasil.Adapter.Bridge, []},
      {BridgeGen, [name: BridgeGen]}
    ]

    options = [strategy: :rest_for_one, name: Yggdrasil.Supervisor]
    Supervisor.start_link(children, options)
  end

  @spec pubsub_adapter() :: Supervisor.child_spec()
  defp pubsub_adapter do
    adapter = Settings.pubsub_adapter!()

    options =
      Settings.pubsub_options!()
      |> Keyword.put(:name, Settings.pubsub_name!())

    Supervisor.child_spec({adapter, options}, type: :supervisor)
  end
end
