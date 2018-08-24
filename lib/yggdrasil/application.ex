defmodule Yggdrasil.Application do
  @moduledoc """
  Module that defines an `Yggdrasil` application.
  """
  use Application

  alias Yggdrasil.Settings
  # alias Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator, as: RabbitGen

  @impl true
  def start(_type, _args) do
    adapter = Settings.yggdrasil_pubsub_adapter()
    options =
      Settings.yggdrasil_pubsub_options()
      |> Keyword.put(:name, Settings.yggdrasil_pubsub_name())

    children = [
      # Core
      Supervisor.child_spec({adapter, options}, type: :supervisor),
      Supervisor.child_spec(
        { Yggdrasil.Publisher.Generator,
          [name: Yggdrasil.Publisher.Generator]
        },
        type: :supervisor
      ),
      Supervisor.child_spec(
        { Yggdrasil.Subscriber.Generator,
          [name: Yggdrasil.Subscriber.Generator]
        },
        type: :supervisor
      ),
      Supervisor.child_spec({Yggdrasil.Registry, []}, []),
      Supervisor.child_spec({Yggdrasil.Backend.Default, []}, []),
      Supervisor.child_spec({Yggdrasil.Transformer.Default, []}, []),
      Supervisor.child_spec({Yggdrasil.Transformer.Json, []}, []),
      Supervisor.child_spec({Yggdrasil.Adapter.Elixir, []}, []),

      # Redis
      Supervisor.child_spec({Yggdrasil.Adapter.Redis, []}, []),

      # Postgres
      Supervisor.child_spec({Yggdrasil.Adapter.Postgres, []}, []),

      # RabbitMQ
      Supervisor.child_spec({Yggdrasil.Adapter.RabbitMQ, []}, []),
      Supervisor.child_spec(
        { Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator,
          [name: Yggdrasil.Subscriber.Adapter.RabbitMQ.Generator]
        },
        type: :supervisor
      )
    ]

    options = [strategy: :rest_for_one, name: Yggdrasil.Supervisor]
    Supervisor.start_link(children, options)
  end
end
