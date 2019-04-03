defmodule Yggdrasil.Settings do
  @moduledoc """
  This module defines the available settings for Yggdrasil.
  """
  use Skogsra

  ###########################
  # Yggdrasil module registry

  @envdoc """
  Module registry.
  """
  app_env :module_registry, :yggdrasil, :module_registry,
    skip_system: true,
    default: :"$yggdrasil_registry"

  ################################
  # Yggdrasil distribution options

  @envdoc """
  Pub-sub adapter to use for channels.
  """
  app_env :pubsub_adapter, :yggdrasil, :pubsub_adapter,
    skip_system: true,
    default: Phoenix.PubSub.PG2

  @envdoc """
  Pub-sub name.
  """
  app_env :pubsub_name, :yggdrasil, :pubsub_name,
    skip_system: true,
    default: Yggdrasil.PubSub

  @envdoc """
  Pub-sub options.
  """
  app_env :pubsub_options, :yggdrasil, :pubsub_options,
    skip_system: true,
    default: [pool_size: 1]

  #############################
  # Yggdrasil publisher options

  @envdoc """
  Yggdrasil publisher options. These options are for `:poolboy`.
  """
  app_env :publisher_options, :yggdrasil, :publisher_options,
    skip_system: true,
    default: [size: 1, max_overflow: 5]
end
