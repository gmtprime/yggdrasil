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

  @doc """
  Whether the `adapter` is connected or not.
  """
  @callback is_connected?(pid) :: true | false

  @doc """
  Checks whether the adapter is connected or not.
  """
  def is_connected?(%Yggdrasil.Channel{decoder: decoder} = channel) do
    name = Yggdrasil.Publisher.Supervisor.gen_adapter_name(channel)
    adapter = decoder.get_adapter()
    registry = Yggdrasil.Publisher.Generator.get_registry()
    adapter.is_connected?({:via, registry, name})
  end

  defmacro __using__(opts \\ []) do
    module = Keyword.get(opts, :module, GenServer) 
    quote do
      @behaviour Yggdrasil.Adapter

      @doc """
      Starts the adapter. Receives an `Yggdrasil.Channel` that contains the
      `decoder` module and the name of the `channel`; the `publisher` PID, and
      a list of `options`.
      """
      def start_link(
        %Yggdrasil.Channel{decoder: decoder, channel: channel},
        publisher,
        options \\ []
      ) do
        adapter = decoder.get_adapter()
        args = %Yggdrasil.Adapter{publisher: publisher, channel: channel}
        module = unquote(module)
        module.start_link(adapter, args, options)
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

      @doc """
      Whether the `_adapter` is connected or not.
      """
      def is_connected?(_adapter), do: true

      defoverridable [start_link: 2, start_link: 3, stop: 1, stop: 2,
                      is_connected?: 1]
    end
  end
end
