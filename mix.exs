defmodule Yggdrasil.Mixfile do
  use Mix.Project

  @version "4.0.0"

  def project do
    [app: :yggdrasil,
     version: @version,
     elixir: "~> 1.6",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: description(),
     package: package(),
     docs: docs(),
     deps: deps()]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Yggdrasil.Application, []}
    ]
  end

  defp deps do
    [{:exreg, "~> 0.0.3"},
     {:phoenix_pubsub, "~> 1.0"},
     {:poolboy, "~> 1.5"},
     {:jason, "~> 1.0"},
     {:skogsra, "~> 0.2"},
     {:uuid, "~> 1.1", only: [:dev, :test]},
     {:ex_doc, "~> 0.18.4", only: :dev},
     {:credo, "~> 0.10", only: :dev}]
  end

  defp docs do
    [source_url: "https://github.com/gmtprime/yggdrasil",
     source_ref: "v#{@version}",
     main: Yggdrasil]
  end

  defp description do
    """
    Yggdrasil is an agnostic publisher/subscriber for Redis, RabbitMQ,
    PostgreSQL and more.
    """
  end

  defp package do
    [maintainers: ["Alexander de Sousa"],
     licenses: ["MIT"],
     links: %{"Github" => "https://github.com/gmtprime/yggdrasil"}]
  end
end
