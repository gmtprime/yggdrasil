defmodule Yggdrasil.Mixfile do
  use Mix.Project

  @version "4.1.2"
  @root "https://github.com/gmtprime/yggdrasil"

  def project do
    [
      app: :yggdrasil,
      version: @version,
      elixir: "~> 1.6",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      name: "Yggdrasil",
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
      {:exreg, "~> 0.0.3"},
      {:phoenix_pubsub, "~> 1.0"},
      {:poolboy, "~> 1.5"},
      {:jason, "~> 1.0"},
      {:skogsra, "~> 1.0"},
      {:uuid, "~> 1.1", only: [:dev, :test]},
      {:ex_doc, "~> 0.18.4", only: :dev},
      {:credo, "~> 0.10", only: :dev}
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
      source_url: @root,
      source_ref: "v#{@version}",
      logo: "logo.png",
      main: Yggdrasil,
      formatters: ["html"],
      groups_for_modules: groups_for_modules()
    ]
  end

  defp groups_for_modules do
    [
      Application: [
        Yggdrasil.Settings,
        Yggdrasil.Application
      ],
      Channels: [
        Yggdrasil.Channel,
        Yggdrasil.Registry
      ],
      Adapters: [
        Yggdrasil.Adapter,
        Yggdrasil.Adapter.Elixir
      ],
      "Subscriber adapters": [
        Yggdrasil.Subscriber.Adapter,
        Yggdrasil.Subscriber.Adapter.Elixir
      ],
      "Publisher adapters": [
        Yggdrasil.Publisher.Adapter,
        Yggdrasil.Publisher.Adapter.Elixir
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
      ]
    ]
  end
end
