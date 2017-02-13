defmodule Yggdrasil.Channel do
  @moduledoc """
  Channel struct definition.

  The attributes are defined as follows:

    + `name` - Name of the channel.
    + `transformer` - Module where the encoding or decoding function is
    defined.
    + `adapter` - Module where the adapter is defined.
    + `namespace` - Namespace of the adapter.
  """

  @doc """
  Channel struct definition.
  """
  defstruct name: nil,
            adapter: nil,
            transformer: Yggdrasil.Transformer.Default,
            namespace: Yggdrasil

  @type t :: %__MODULE__{
    name: any(),
    adapter: module(),
    transformer: module(),
    namespace: atom()
  }
end
