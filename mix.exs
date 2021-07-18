defmodule Yggdrasil.Mixfile do
  use Mix.Project

  @version "6.0.0"
  @root "https://github.com/gmtprime/yggdrasil"

  def project do
    [
      name: "Yggdrasil",
      app: :yggdrasil,
      version: @version,
      elixir: "~> 1.12",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  #############
  # Application

  def application do
    [
      extra_applications: [:logger],
      mod: {Yggdrasil.Application, []}
    ]
  end

  defp deps do
    [
      {:exreg, "~> 1.0"},
      {:phoenix_pubsub, "~> 2.0"},
      {:poolboy, "~> 1.5"},
      {:jason, "~> 1.2"},
      {:skogsra, "~> 2.3"},
      {:ex_doc, "~> 0.24", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false}
    ]
  end

  #########
  # Package

  defp package do
    [
      description: "Agnostic pub/sub with Redis, RabbitMQ and Postgres support",
      files: ["lib", "priv", "mix.exs", "README.md", "CHANGELOG.md"],
      maintainers: ["Alexander de Sousa"],
      licenses: ["MIT"],
      links: %{
        "Changelog" => "#{@root}/blob/master/CHANGELOG.md",
        "Github" => @root
      }
    ]
  end

  ###############
  # Documentation

  defp docs do
    [
      main: "readme",
      logo: "logo.png",
      source_url: @root,
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: groups_for_modules()
    ]
  end

  defp groups_for_modules do
    [
      Yggdrasil: [
        Yggdrasil
      ],
      Application: [
        Yggdrasil.Settings
      ],
      Channels: [
        Yggdrasil.Channel,
        Yggdrasil.Registry
      ],
      Adapters: [
        Yggdrasil.Adapter,
        Yggdrasil.Adapter.Elixir,
        Yggdrasil.Adapter.Bridge
      ],
      "Subscriber adapters": [
        Yggdrasil.Subscriber.Adapter,
        Yggdrasil.Subscriber.Adapter.Elixir,
        Yggdrasil.Subscriber.Adapter.Bridge
      ],
      "Publisher adapters": [
        Yggdrasil.Publisher.Adapter,
        Yggdrasil.Publisher.Adapter.Elixir,
        Yggdrasil.Publisher.Adapter.Bridge
      ],
      Backends: [
        Yggdrasil.Backend,
        Yggdrasil.Backend.Default
      ],
      Transformers: [
        Yggdrasil.Transformer,
        Yggdrasil.Transformer.Default,
        Yggdrasil.Transformer.Json
      ],
      "Message distribution": [
        Yggdrasil.Publisher,
        Yggdrasil.Publisher.Generator,
        Yggdrasil.Subscriber.Generator,
        Yggdrasil.Subscriber.Distributor,
        Yggdrasil.Subscriber.Manager,
        Yggdrasil.Subscriber.Publisher
      ],
      "Bridge subscribers": [
        Yggdrasil.Adapter.Bridge.Generator,
        Yggdrasil.Adapter.Bridge.Subscriber
      ]
    ]
  end
end
