defmodule Yggdrasil.Settings do
  @moduledoc """
  This module defines the available settings for Yggdrasil.
  """
  use Skogsra

  ############################
  # Yggdrasil process registry

  @doc """
  Process registry.

  ```
  config :yggdrasil,
    process_registry: ExReg
  ```
  """
  app_env :yggdrasil_process_registry, :yggdrasil, :process_registry,
    skip_system: true,
    default: ExReg

  ############################
  # Yggdrasil registry options

  @doc """
  Module registry table name.

  ```
  config :yggdrasil,
    module_registry: :yggdrasil_registry
  ```
  """
  app_env :yggdrasil_module_registry, :yggdrasil, :module_registry,
    skip_system: true,
    default: :yggdrasil_registry

  ################################
  # Yggdrasil distribution options

  @doc """
  Pub-sub adapter to use for channels. Default value is `Phoenix.PubSub.PG2`.

  ```
  config :yggdrasil,
    pubsub_adapter: Phoenix.PubSub.PG2
  ```
  """
  app_env :yggdrasil_pubsub_adapter, :yggdrasil, :pubsub_adapter,
    skip_system: true,
    default: Phoenix.PubSub.PG2

  @doc """
  Pub-sub name. By default is `Yggdrasil.PubSub`.

  ```
  config :yggdrasil,
    pubsub_name: Yggdrasil.PubSub
  ```
  """
  app_env :yggdrasil_pubsub_name, :yggdrasil, :pubsub_name,
    skip_system: true,
    default: Yggdrasil.PubSub

  @doc """
  Pub-sub options. By default are `[pool_size: 1]`.

  ```
  config :yggdrasil,
    pubsub_options: [pool_size: 1]
  ```
  """
  app_env :yggdrasil_pubsub_options, :yggdrasil, :pubsub_options,
    skip_system: true,
    default: [pool_size: 1]

  #############################
  # Yggdrasil publisher options

  @doc """
  Yggdrasil publisher options. This options are for `:poolboy`. Defaults to
  `[size: 5, max_overflow: 10]`.

  ```
  config :yggdrasil,
    publisher_options: [size: 5, max_overflow: 10]
  ```
  """
  app_env :yggdrasil_publisher_options, :yggdrasil, :publisher_options,
    skip_system: true,
    default: [size: 5, max_overflow: 10]
end
