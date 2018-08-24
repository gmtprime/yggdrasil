defmodule Yggdrasil.Settings.Redis do
  @moduledoc """
  This module defines the available settings for Redis in Yggdrasil.
  """
  use Skogsra

  #######################################################
  # Redis connection default variables for default domain

  @doc """
  Redis hostname. Defaults to `"localhost"`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_REDIS_HOSTNAME`.
    2. The configuration file.
    3. The default value `"localhost"`

  If the hostname is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_REDIS_HOSTNAME` where `NAMESPACE`
  is the snake case version of the actual namespace e.g `MyApp.Namespace` would
  be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, <NAMESPACE>
    redis: [hostname: "localhost"]
  ```
  """
  app_env :yggdrasil_redis_hostname, :yggdrasil, :hostname,
    default: "localhost",
    domain: :redis

  @doc """
  Redis port. Defaults to `6379`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_REDIS_PORT`.
    2. The configuration file.
    3. The default value `6379`.

  If the port is defined using a namespace, then the name of the OS variable
  should be `$<NAMESPACE>_YGGDRASIL_REDIS_PORT` where `NAMESPACE` is the snake
  case version of the actual namespace e.g `MyApp.Namespace` would
  be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, <NAMESPACE>
    redis: [port: 6379]
  ```
  """
  app_env :yggdrasil_redis_port, :yggdrasil, :port,
    default: 6379,
    domain: :redis

  @doc """
  Redis password. Defaults to `nil`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_REDIS_PASSWORD`.
    2. The configuration file.
    3. The default value `nil`.

  If the password is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_REDIS_PASSWORD` where `NAMESPACE`
  is the snake case version of the actual namespace e.g `MyApp.Namespace` would
  be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, <NAMESPACE>
    redis: [password: nil]
  ```
  """
  app_env :yggdrasil_redis_password, :yggdrasil, :password,
    domain: :redis

  @doc """
  Redis database. Defaults to `0`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_REDIS_DATABASE`.
    2. The configuration file.
    3. The default value `0`.

  If the database is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_REDIS_DATABASE` where `NAMESPACE`
  is the snake case version of the actual namespace e.g `MyApp.Namespace` would
  be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, <NAMESPACE>
    redis: [database: 0]
  ```
  """
  app_env :yggdrasil_redis_database, :yggdrasil, :database,
    default: 0,
    domain: :redis
end
