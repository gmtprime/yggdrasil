defmodule Yggdrasil do
  use Application

  @generator Yggdrasil.Publisher.Generator
  @broker Yggdrasil.Broker

  @doc """
  Subscribes to a `channel`.
  """
  def subscribe(channel) do
    Yggdrasil.Backend.join(channel, self())
  end

  @doc """
  Unsubscribe from a `channel`.
  """
  def unsubscribe(channel) do
    Yggdrasil.Backend.leave(channel, self())
  end

  @doc """
  Emits a `message` in a `channel`.
  """
  def publish(channel, message) do
    Yggdrasil.Backend.emit(channel, message)
  end

  ##
  # Gets broker name.
  defp get_broker_name do
    Application.get_env(:yggdrasil, :broker_name, @broker)
  end

  ##
  # Monitors table.
  defp get_monitors_table do
    :ets.new(:monitors, [:set, :public, write_concurrency: false,
                         read_concurrency: true])
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    broker_name = get_broker_name()
    monitors = get_monitors_table()

    children = [
      supervisor(@generator, [[name: @generator]]),
      worker(@broker, [@generator, monitors, [name: broker_name]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :rest_for_one, name: Yggdrasil.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
