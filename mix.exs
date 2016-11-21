defmodule Yggdrasil.Mixfile do
  use Mix.Project

  @version "3.0.0"

  def project do
    [app: :yggdrasil,
     version: @version,
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description,
     package: package,
     docs: docs,
     deps: deps]
  end

  def application do
    [applications: [:logger, :phoenix_pubsub, :redix_pubsub, :amqp, :postgrex],
     mod: {Yggdrasil, []}]
  end

  @amqp_client "https://github.com/jbrisbin/amqp_client.git"

  defp deps do
    [{:exreg, "~> 0.0.3"},
     {:phoenix_pubsub, "~> 1.0"},
     {:poolboy, "~> 1.5"},
     {:redix_pubsub, ">= 0.0.0"},
     {:amqp, "~> 0.1.5"},
     {:amqp_client, git: @amqp_client, override: true},
     {:postgrex, ">= 0.0.0"},
     {:connection, "~> 1.0.4"},
     {:version_check, "~> 0.1"},
     {:uuid, "~> 1.1.4", only: [:dev, :test]},
     {:earmark, ">= 0.0.0", only: :dev},
     {:ex_doc, "~> 0.13", only: :dev},
     {:credo, "~> 0.5", only: [:dev, :docs]},
     {:inch_ex, ">= 0.0.0", only: [:dev, :docs]}]
  end

  defp docs do
    [source_url: "https://github.com/gmtprime/yggdrasil",
     source_ref: "v#{@version}",
     main: Yggdrasil]
  end

  defp description do
    """
    Yggdrasil is a pubsub connection manager that works for Redis, RabbitMQ and
    PostgreSQL by default, but with the possibilty to extend functionality to
    other brokers.
    """
  end

  defp package do
    [maintainers: ["Alexander de Sousa"],
     licenses: ["MIT"],
     links: %{"Github" => "https://github.com/gmtprime/yggdrasil"}]
  end
end
