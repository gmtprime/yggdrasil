defmodule Yggdrasil.Util.Forwarder do
  use GenEvent

  def start_link(opts \\ []) do
    {:ok, manager} = GenEvent.start_link opts
    GenEvent.add_mon_handler manager, __MODULE__, %{}
    {:ok, manager}
  end

  def set_parent(forwarder, pid \\ nil) do
    parent = if pid == nil do self() else pid end
    ref = make_ref()
    GenEvent.notify forwarder, {:_parent, ref, parent}
    %{forwarder: forwarder, ref: ref}
  end

  def notify(%{forwarder: forwarder, ref: ref}, event) do
    GenEvent.notify forwarder, {ref, event}
  end

  #####################
  # GenEvent callbacks.

  def handle_event({:_parent, ref, pid}, state), do:
    {:ok, Map.put_new(state, ref, pid)}
  def handle_event({ref, event}, state) do
    case Map.fetch state, ref do
      {:ok, parent} ->
        send parent, event
      _ -> :ok
    end
    {:ok, state}
  end
  def handle_event(_any, state), do:
    {:ok, state}
end
