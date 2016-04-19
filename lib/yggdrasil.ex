defmodule Yggdrasil do
  use Application

  @proxy_name Yggdrasil.Proxy
  @broker_sup_name Yggdrasil.MessengerSupervisor
  @feed_name Yggdrasil.Feed
  @forwarder_name Yggdrasil.Util.Forwarder
  @messengers_table Yggdrasil.Messengers
  @subscribers_table Yggdrasil.Subscribers
  
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    messengers = :ets.new @messengers_table,
                          [:set, :named_table, :public, read_concurrency: true]
    subscribers = :ets.new @subscribers_table,
                           [:set, :named_table, :public,
                            read_concurrency: true]
    children = [
      worker(@proxy_name, [[name: @proxy_name]]),
      supervisor(@broker_sup_name, [[name: @broker_sup_name]]),
      worker(@feed_name,
             [@broker_sup_name, @proxy_name, subscribers, messengers,
              nil, [name: @feed_name]])
    ]
    opts = [strategy: :rest_for_one, name: Yggdrasil.Supervisor]
    Supervisor.start_link children, opts
  end
end
