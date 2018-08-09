defmodule Yggdrasil.Mixfile do
  use Mix.Project

  @version "3.3.4"

  def project do
    [app: :yggdrasil,
     version: @version,
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     docs: docs(),
     deps: deps()]
  end

  def application do
    [applications: [:lager, :logger, :poolboy, :phoenix_pubsub, :redix_pubsub,
                    :amqp, :postgrex],
     mod: {Yggdrasil, []}]
  end

  defp deps do
    [{:exreg, "~> 0.0.3"},
     {:phoenix_pubsub, "~> 1.0"},
     {:poolboy, "~> 1.5"},
     {:redix_pubsub, "~> 0.4"},
     {:amqp, "~> 1.0"},
     {:postgrex, "~> 0.13"},
     {:connection, "~> 1.0"},
     {:jason, "~> 1.0"},
     {:skogsra, "~> 0.2"},
     {:uuid, "~> 1.1", only: [:dev, :test]},
     {:ex_doc, "~> 0.18", only: :dev},
     {:credo, "~> 0.9", only: [:dev, :docs]}]
  end

  defp docs do
    [source_url: "https://github.com/gmtprime/yggdrasil",
     source_ref: "v#{@version}",
     main: Yggdrasil]
  end

  defp description do
    """
    Yggdrasil is an agnostic publisher/subscriber for Redis, RabbitMQ and
    PostgreSQL.
    """
  end

  defp package do
    [maintainers: ["Alexander de Sousa"],
     licenses: ["MIT"],
     links: %{"Github" => "https://github.com/gmtprime/yggdrasil"}]
  end
end
