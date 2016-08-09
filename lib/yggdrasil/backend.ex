defmodule Yggdrasil.Channel do
  @moduledoc """
  Channel definition.
  """
  defstruct [:channel, :decoder]
  @type t :: %__MODULE__{channel: channel :: term, decoder: decoder :: atom} 
end

defmodule Yggdrasil.Backend do
  @moduledoc """
  YProcess backend implementation for Yggdrasil. It is a general wrapper over
  other YProcesss backends.
  """
  use YProcess.Backend

  alias Yggdrasil.Channel
  alias Yggdrasil.Broker

  @broker_name Yggdrasil.Broker
  @backend YProcess.Backend.PhoenixPubSub

  ##
  # Gets the backend module.
  defp get_backend do
    backend = Application.get_env(:y_process, :backend, @backend)
    Application.get_env(:yggdrasil, :backend, backend)
  end

  @doc """
  Creates a `channel` using the backend from the configuration.
  """
  def create(%Channel{channel: channel}) do
    create(channel)
  end
  def create(channel) do
    module = get_backend()
    module.create(channel)
  end

  @doc """
  Deletes a `channel` using the backend from the configuration.
  """
  def delete(%Channel{channel: channel}) do
    delete(channel)
  end
  def delete(channel) do
    module = get_backend()
    module.delete(channel)
  end

  @doc """
  Makes the process `pid` join a `channel` using the the backend from the
  configuration.
  """
  def join(%Channel{channel: channel} = info, pid) do
    case Broker.subscribe(@broker_name, info, pid) do
      :ok -> join(channel, pid)
      error -> error
    end
  end
  def join(channel, pid) do
    module = get_backend()
    module.join(channel, pid)
  end

  @doc """
  Makes the process `pid` leave a `channel` using the backend from the
  configuration.
  """
  def leave(%Channel{channel: channel} = info, pid) do
    case Broker.unsubscribe(@broker_name, info, pid) do
      :ok -> leave(channel, pid)
      error -> error
    end
  end
  def leave(channel, pid) do
    module = get_backend()
    module.leave(channel, pid)
  end

  @doc """
  Emits a `message` in a `channel` using the backend from the configuration.
  """
  def emit(%Channel{channel: channel}, message) do
    emit(channel, message)
  end
  def emit(channel, message) do
    module = get_backend()
    module.emit(channel, message)
  end
end
