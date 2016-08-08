defmodule Yggdrasil.Adapter do
  @moduledoc """
  This module defines the functions `start_link/2`, `start_link/3`, `stop/1`
  and `stop/2` necessary to start and stop an adapter.
  """
  ##
  # Adapter arguments:
  #   * `:publisher` - Publisher `pid` or name.
  #   * `:channel` - Channel name.
  defstruct [:publisher, :channel]

  defmacro __using__(opts \\ []) do
    module = Keyword.get(opts, :module, GenServer) 
    quote do
      @doc """
      Starts the adapter. Receives a `decoder`
      """
      def start_link(
        %Yggdrasil.Channel{decoder: decoder, channel: channel},
        publisher,
        opts \\ []
      ) do
        adapter = decoder.get_adapter()
        args = %Yggdrasil.Adapter{publisher: publisher, channel: channel}
        module = unquote(module)
        module.start_link(adapter, args, opts)
      end

      @doc """
      Stops the adapter using the server `pid` and a `reason`. By default,
      `reason` is `:normal`.
      """
      def stop(pid, reason \\ :normal) do
        module = unquote(module)
        exports = module.module_info()[:exports]
        has_function? = 2 in Keyword.get_values(exports, :stop)
        if has_function? do
          module.stop(pid, reason)
        else
          GenServer.stop(pid, reason)
        end
      end

      defoverridable [start_link: 2, start_link: 3, stop: 1, stop: 2]
    end
  end
end
