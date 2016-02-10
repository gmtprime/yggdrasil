defmodule Yggdrasil.Broker.RabbitMQConfig do
  defmodule Config do
    defstruct host: nil,
              port: nil,
              username: nil,
              password: nil,
              virtual_host: nil
  end

  def settings, do: [:host, :port, :username, :password, :virtual_host]

  def fetch_env do
    app_config = settings
      |> Enum.reduce(%{}, fn (key, config) -> load_config_key(config, key) end)
    struct(Config, app_config)
  end

  def load_config_key(config, key) do
    case Application.get_env(:amqp, key) do
      :nil -> config
      value -> Dict.put(config, key, value)
    end
  end
end
