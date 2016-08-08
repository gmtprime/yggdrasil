defmodule Yggdrasil.Mixfile do
  use Mix.Project

  @version "2.0.0"

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
    [applications: [:redix_pubsub, :amqp],
     mod: {Yggdrasil, []}]
  end

  defp deps do
    [{:y_process, "~> 0.1.3"},
     {:exreg, "~> 0.0.3"},
     {:redix_pubsub, ">= 0.0.0"},
     {:amqp_client, git: "https://github.com/jbrisbin/amqp_client.git",
      override: true},
     {:amqp, "~> 0.1.4"},
     {:connection, "~> 1.0.4"},
     {:earmark, ">= 0.0.0", only: :dev},
     {:ex_doc, "~> 0.13", only: :dev},
     {:credo, "~> 0.4.7", only: [:dev, :docs]},
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
