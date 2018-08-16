defmodule Yggdrasil.Transformer.Default do
  @moduledoc """
  Does not do anything to the messages and sends them as is.
  """
  use Yggdrasil.Transformer, name: :default
end
