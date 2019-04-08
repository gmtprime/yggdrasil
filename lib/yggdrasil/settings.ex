defmodule Yggdrasil.Settings do
  @moduledoc """
  This module defines the available settings for Yggdrasil.
  """
  use Skogsra

  ###########################
  # Yggdrasil module registry

  @envdoc """
  Module registry.

      iex> Yggdrasil.Settings.module_registry!()
      :"$yggdrasil_registry"
  """
  app_env :module_registry, :yggdrasil, :module_registry,
    skip_system: true,
    default: :"$yggdrasil_registry"

  ################################
  # Yggdrasil distribution options

  @envdoc """
  Pub-sub adapter to use for channels.

      iex> Yggdrasil.Settings.pubsub_adapter!()
      Phoenix.PubSub.PG2
  """
  app_env :pubsub_adapter, :yggdrasil, :pubsub_adapter,
    skip_system: true,
    default: Phoenix.PubSub.PG2

  @envdoc """
  Pub-sub name.

      iex> Yggdrasil.Settings.pubsub_name!()
      Yggdrasil.PubSub
  """
  app_env :pubsub_name, :yggdrasil, :pubsub_name,
    skip_system: true,
    default: Yggdrasil.PubSub

  @envdoc """
  Pub-sub options.

      iex> Yggdrasil.Settings.pubsub_options!()
      [pool_size: 1]
  """
  app_env :pubsub_options, :yggdrasil, :pubsub_options,
    skip_system: true,
    default: [pool_size: 1]

  #############################
  # Yggdrasil publisher options

  @envdoc """
  Yggdrasil publisher options. These options are for `:poolboy`.

      iex> Yggdrasil.Settings.publisher_options!()
      [size: 1, max_overflow: 5]
  """
  app_env :publisher_options, :yggdrasil, :publisher_options,
    skip_system: true,
    default: [size: 1, max_overflow: 5]
end
