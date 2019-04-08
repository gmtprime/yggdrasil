defmodule Yggdrasil.Channel do
  @moduledoc """
  Channel struct definition.

  The attributes are defined as follows:

    + `name` - Name of the channel.
    + `transformer` - Module where the encoding or decoding function is
    defined.
    + `adapter` - Module where the adapter is defined or identifier.
    + `namespace` - Namespace of the adapter.
    + `backend` - Distributor backend.
    + `metadata` - Metadata for the channel. Used internally.
  """

  @doc """
  Channel struct definition.
  """
  defstruct name: nil,
            adapter: :elixir,
            transformer: nil,
            namespace: nil,
            backend: nil,
            metadata: nil

  @typedoc """
  Channel.
  """
  @type t :: %__MODULE__{
          name: any(),
          adapter: module(),
          transformer: module(),
          namespace: atom(),
          backend: module(),
          metadata: term()
        }
end
