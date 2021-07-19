defmodule Yggdrasil.Config do
  @moduledoc """
  This module defines the available config variables for Yggdrasil.
  """
  use Skogsra

  ###########################
  # Yggdrasil module registry

  @envdoc """
  Module registry.

      iex> Yggdrasil.Config.module_registry!()
      :"$yggdrasil_registry"
  """
  app_env :module_registry, :yggdrasil, :module_registry,
    binding_skip: [:system],
    default: :"$yggdrasil_registry"

  #############################
  # Yggdrasil publisher options

  @envdoc """
  Yggdrasil publisher options. These options are for `:poolboy`.

      iex> Yggdrasil.Config.publisher_options!()
      [size: 1, max_overflow: 5]
  """
  app_env :publisher_options, :yggdrasil, :publisher_options,
    binding_skip: [:system],
    default: [size: 1, max_overflow: 5]
end
