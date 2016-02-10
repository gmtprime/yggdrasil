defmodule Yggdrasil.MessengerSupervisor do
  use Supervisor

  #############
  # Client API.

  @doc """
  Starts a messenger.
  """
  def start_broker(supervisor, broker, channel, proxy, forwarder \\ nil,
                   opts \\ []) do
    args = [broker, channel, proxy, forwarder, opts]
    Supervisor.start_child supervisor, args
  end

  @doc """
  Starts a redis supervisor.
  """
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, nil, opts)
  end


  #######################
  # Supervisor callbacks.
  def init(nil) do
    children = [worker(Yggdrasil.Messenger, [], restart: :temporary)]
    supervise(children, strategy: :simple_one_for_one)
  end
end
