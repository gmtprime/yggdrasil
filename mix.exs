defmodule Yggdrasil.Mixfile do
  use Mix.Project

  @version "2.0.8"

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

  defp deps do
    [{:y_process, "~> 0.2.1"},
     {:exreg, "~> 0.0.3"},
     {:redix_pubsub, ">= 0.0.0"},
     {:amqp, "~> 0.1.5"},
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
    Yggdrasil is an app to manage channels subscriptions (open connections)
    from several brokers and redistributing the messages received from them to
    the subscribed Elixir processes.
    """
  end

  defp package do
    [maintainers: ["Alexander de Sousa"],
     licenses: ["MIT"],
     links: %{"Github" => "https://github.com/gmtprime/yggdrasil"}]
  end
end
