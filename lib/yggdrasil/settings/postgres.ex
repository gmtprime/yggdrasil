defmodule Yggdrasil.Settings.Postgres do
  @moduledoc """
  This module defines the available settings for PostgreSQL in Yggdrasil.
  """
  use Skogsra

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
  config :yggdrasil, <NAMESPACE>
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
  config :yggdrasil, <NAMESPACE>
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
  config :yggdrasil, <NAMESPACE>
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
  config :yggdrasil, <NAMESPACE>
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
  config :yggdrasil, <NAMESPACE>
    postgres: [database: "postgres"]
  ```
  """
  app_env :yggdrasil_postgres_database, :yggdrasil, :database,
    default: "postgres",
    domain: :postgres

  @doc """
  Postgres max retries for the backoff algorithm. Defaults to `12`.

  It looks for the value following this order.

    1. The OS environment variable `$YGGDRASIL_POSTGRES_MAX_RETRIES`.
    2. The configuration file.
    3. The default value `12`.

  If the max retries are defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_POSTGRES_MAX_RETRIES` where
  `NAMESPACE` is the snake case version of the actual namespace e.g.
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, <NAMESPACE>,
    postgres: [max_retries: 12]
  ```

  The backoff algorithm is exponential:
  ```
  backoff_time = pow(2, retries) * random(1, slot) ms
  ```
  when `retries <= MAX_RETRIES` and `slot` is given by the configuration
  variable `YGGDRASIL_POSTGRES_SLOT_SIZE` (defaults to `100` ms).
  """
  app_env :yggdrasil_postgres_max_retries, :yggdrasil, :max_retries,
    default: 12,
    domain: :postgres

  @doc """
  Postgres slot size for the backoff algorithm. Defaults to `100`.

  It looks for the value following this order.

    1. The OS environment variable `$YGGDRASIL_POSTGRES_SLOT_SIZE`.
    2. The configuration file.
    3. The default value `100`.

  If slot sizes is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_POSTGRES_SLOT_SIZE` where
  `NAMESPACE` is the snake case version of the actual namespace e.g.
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, <NAMESPACE>,
    postgres: [slot_size: 100]
  ```
  """
  app_env :yggdrasil_postgres_slot_size, :yggdrasil, :slot_size,
    default: 100,
    domain: :postgres
end
