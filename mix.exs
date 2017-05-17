defmodule Yggdrasil.Mixfile do
  use Mix.Project

  @version "3.0.4"

  def project do
    [app: :yggdrasil,
     version: @version,
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     docs: docs(),
     deps: deps()]
  end

  def application do
    [applications: [:logger, :poolboy, :phoenix_pubsub, :redix_pubsub, :amqp,
                    :postgrex],
     mod: {Yggdrasil, []}]
  end

  defp deps do
    [{:exreg, "~> 0.0.3"},
     {:phoenix_pubsub, "~> 1.0"},
     {:poolboy, "~> 1.5"},
     {:redix_pubsub, ">= 0.0.0"},
     {:amqp, "~> 0.2"},
     {:postgrex, ">= 0.0.0"},
     {:connection, "~> 1.0"},
     {:version_check, "~> 0.1"},
     {:uuid, "~> 1.1", only: [:dev, :test]},
     {:ex_doc, "~> 0.15", only: :dev},
     {:credo, "~> 0.7", only: [:dev, :docs]},
     {:inch_ex, "~> 0.5", only: [:dev, :docs]}]
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
