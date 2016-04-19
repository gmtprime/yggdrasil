defmodule Yggdrasil.Mixfile do
  use Mix.Project

  @version "1.2.3"

  def project do
    [app: :yggdrasil,
     version: @version,
     build_path: "./_build",
     config_path: "./config/config.exs",
     deps_path: "./deps",
     lockfile: "./mix.lock",
     elixir: "~> 1.2",
     package: package,
     description: description,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :amqp, :postgrex],
     mod: {Yggdrasil, []}]
  end

  defp deps do
    [{:exredis, ">= 0.2.4"},
     {:amqp, "0.1.4"},
     {:postgrex, ">= 0.11.0"}]
  end

  defp description do
    """
    Yggdrasil is an app to manage subscriptions to several brokers. It has
    simple implementations for Redis, RabbitMQ and Postgres brokers, but they
    can easily be extended. Also provides a `behaviour` to define custom
    brokers. 
    """
  end

  defp package do
    [files: ["lib", "test", "mix.exs", "README.md", "mix.lock", "LICENSE"],
     maintainers: ["Alexander de Sousa"],
     licenses: ["MIT"],
     links: %{"Github" => "https://github.com/gmtprime/yggdrasil"}]
  end
end
