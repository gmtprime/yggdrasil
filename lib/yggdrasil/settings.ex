defmodule Yggdrasil.Settings do
  @moduledoc """
  This module defines the available settings for Yggdrasil.
  """
  use Skogsra

  @doc false
  def gen_env_name(namespace, key, default \\ "_YGGDRASIL_") do
    prefix =
      namespace
      |> Atom.to_string()
      |> String.trim("Elixir.")
      |> String.upcase()
      |> String.split(".")
      |> Enum.join("_")
    name = key |> Atom.to_string() |> String.upcase()
    prefix <> default <> name
  end

  @doc """
  Process registry.

  ```
  config :yggdrasil,
    registry: ExReg
  ```
  """
  app_env :registry, :yggdrasil, :registry,
    default: ExReg

  @doc """
  Pub-sub adapter to use for channels. Default value is `Phoenix.PubSub.PG2`.

  ```
  config :yggdrasil,
    pubsub_adapter: Phoenix.PubSub.PG2
  ```
  """
  app_env :pubsub_adapter, :yggdrasil, :pubsub_adapter,
    default: Phoenix.PubSub.PG2

  @doc """
  Pub-sub name. By default is `Yggdrasil.PubSub`.

  ```
  config :yggdrasil,
    pubsub_name: Yggdrasil.PubSub
  ```
  """
  app_env :pubsub_name, :yggdrasil, :pubsub_name,
    default: Yggdrasil.PubSub

  @doc """
  Pub-sub options. By default are `[pool_size: 1]`.

  ```
  config :yggdrasil,
    pubsub_options: [pool_size: 1]
  ```
  """
  app_env :pubsub_options, :yggdrasil, :pubsub_options,
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
    default: [size: 5, max_overflow: 10]

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
  config :yggdrasil, [NAMESPACE]
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
  config :yggdrasil, [NAMESPACE]
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
  config :yggdrasil, [NAMESPACE]
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
  config :yggdrasil, [NAMESPACE]
    redis: [database: 0]
  ```
  """
  app_env :yggdrasil_redis_database, :yggdrasil, :database,
    default: 0,
    domain: :redis

  ##########################################################
  # RabbitMQ connection default variables for default domain

  @doc """
  RabbitMQ hostname. Defaults to `"localhost"`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_RABBITMQ_HOSTNAME`.
    2. The configuration file.
    3. The default value `"localhost"`

  If the hostname is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_RABBITMQ_HOSTNAME` where
  `NAMESPACE` is the snake case version of the actual namespace e.g
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    rabbitmq: [hostname: "localhost"]
  ```
  """
  app_env :yggdrasil_rabbitmq_hostname, :yggdrasil, :hostname,
    default: "localhost",
    domain: :rabbitmq

  @doc """
  RabbitMQ port. Defaults to `5672`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_RABBITMQ_PORT`.
    2. The configuration file.
    3. The default value `5672`.

  If the port is defined using a namespace, then the name of the OS variable
  should be `$<NAMESPACE>_YGGDRASIL_RABBITMQ_PORT` where `NAMESPACE` is the
  snake case version of the actual namespace e.g `MyApp.Namespace` would
  be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    rabbitmq: [port: 5672]
  ```
  """
  app_env :yggdrasil_rabbitmq_port, :yggdrasil, :port,
    default: 5672,
    domain: :rabbitmq

  @doc """
  RabbitMQ username. Defaults to `"guest"`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_RABBITMQ_USERNAME`.
    2. The configuration file.
    3. The default value `"guest"`.

  If the username is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_RABBITMQ_USERNAME` where
  `NAMESPACE` is the snake case version of the actual namespace e.g
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    rabbitmq: [username: "guest"]
  ```
  """
  app_env :yggdrasil_rabbitmq_username, :yggdrasil, :username,
    default: "guest",
    domain: :rabbitmq

  @doc """
  RabbitMQ password. Defaults to `"guest"`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_RABBITMQ_PASSWORD`.
    2. The configuration file.
    3. The default value `"guest"`.

  If the password is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_RABBITMQ_PASSWORD` where
  `NAMESPACE` is the snake case version of the actual namespace e.g
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    rabbitmq: [password: "guest"]
  ```
  """
  app_env :yggdrasil_rabbitmq_password, :yggdrasil, :password,
    default: "guest",
    domain: :rabbitmq

  @doc """
  RabbitMQ virtual host. Defaults to `"/"`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_RABBITMQ_VIRTUAL_HOST`.
    2. The configuration file.
    3. The default value `"/"`.

  If the virtual host is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_RABBITMQ_VIRTUAL_HOST` where
  `NAMESPACE` is the snake case version of the actual namespace e.g
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    rabbitmq: [virtual_host: "/"]
  ```
  """
  app_env :yggdrasil_rabbitmq_virtual_host, :yggdrasil, :virtual_host,
    default: "/",
    domain: :rabbitmq

  @doc """
  RabbitMQ subscriber options. They are options for `:poolboy`. Defaults to
  `[size: 5, max_overflow: 10].`

  ```
  config :yggdrasil, [NAMESPACE]
    rabbitmq: [subscriber_options: [size: 5, max_overflow: 10]]
  ```
  """
  app_env :yggdrasil_rabbitmq_subscriber_options, :yggdrasil, :subscriber_options,
    default: [size: 5, max_overflow: 10],
    domain: :rabbitmq

  ##########################################################
  # Postgres connection default variables for default domain

  @doc """
  Postgres hostname. Defaults to `"localhost"`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_POSTGRES_HOSTNAME`.
    2. The configuration file.
    3. The default value `"localhost"`

  If the hostname is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_POSTGRES_HOSTNAME` where
  `NAMESPACE` is the snake case version of the actual namespace e.g
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    potgres: [hostname: "localhost"]
  ```
  """
  app_env :yggdrasil_postgres_hostname, :yggdrasil, :hostname,
    default: "localhost",
    domain: :postgres

  @doc """
  Postgres port. Defaults to `5432`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_POSTGRES_PORT`.
    2. The configuration file.
    3. The default value `5432`.

  If the port is defined using a namespace, then the name of the OS variable
  should be `$<NAMESPACE>_YGGDRASIL_POSTGRES_PORT` where `NAMESPACE` is the
  snake case version of the actual namespace e.g `MyApp.Namespace` would
  be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    postgres: [port: 5432]
  ```
  """
  app_env :yggdrasil_postgres_port, :yggdrasil, :port,
    default: 5432,
    domain: :postgres

  @doc """
  Postgres username. Defaults to `"postgres"`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_POSTGRES_USERNAME`.
    2. The configuration file.
    3. The default value `"postgres"`.

  If the username is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_POSTGRES_USERNAME` where
  `NAMESPACE` is the snake case version of the actual namespace e.g
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    postgres: [username: "postgres"]
  ```
  """
  app_env :yggdrasil_postgres_username, :yggdrasil, :username,
    default: "postgres",
    domain: :postgres

  @doc """
  Postgres password. Defaults to `"postgres"`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_POSTGRES_PASSWORD`.
    2. The configuration file.
    3. The default value `"postgres"`.

  If the password is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_POSTGRES_PASSWORD` where
  `NAMESPACE` is the snake case version of the actual namespace e.g
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    postgres: [password: "postgres"]
  ```
  """
  app_env :yggdrasil_postgres_password, :yggdrasil, :password,
    default: "postgres",
    domain: :postgres

  @doc """
  Postgres database. Defaults to `"postgres"`.

  It looks for the value following this order:

    1. The OS environment variable `$YGGDRASIL_POSTGRES_DATABASE`.
    2. The configuration file.
    3. The default value `"postgres"`.

  If the database is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_POSTGRES_DATABASE` where
  `NAMESPACE` is the snake case version of the actual namespace e.g
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, [NAMESPACE]
    postgres: [database: "postgres"]
  ```
  """
  app_env :yggdrasil_postgres_database, :yggdrasil, :database,
    default: "postgres",
    domain: :postgres
end
