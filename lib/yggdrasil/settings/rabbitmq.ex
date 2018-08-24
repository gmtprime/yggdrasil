defmodule Yggdrasil.Settings.RabbitMQ do
  @moduledoc """
  This module defines the available settings for RabbitMQ in Yggdrasil.
  """
  use Skogsra

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
  config :yggdrasil, <NAMESPACE>
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
  config :yggdrasil, <NAMESPACE>
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
  config :yggdrasil, <NAMESPACE>
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
  config :yggdrasil, <NAMESPACE>
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
  config :yggdrasil, <NAMESPACE>
    rabbitmq: [virtual_host: "/"]
  ```
  """
  app_env :yggdrasil_rabbitmq_virtual_host, :yggdrasil, :virtual_host,
    default: "/",
    domain: :rabbitmq

  @doc """
  RabbitMQ max retries for the backoff algorithm. Defaults to `12`.

  It looks for the value following this order.

    1. The OS environment variable `$YGGDRASIL_RABBITMQ_MAX_RETRIES`.
    2. The configuration file.
    3. The default value `12`.

  If the max retries are defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_RABBITMQ_MAX_RETRIES` where
  `NAMESPACE` is the snake case version of the actual namespace e.g.
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, <NAMESPACE>,
    rabbitmq: [max_retries: 12]
  ```

  The backoff algorithm is exponential:
  ```
  backoff_time = pow(2, retries) * random(1, slot) ms
  ```
  when `retries <= MAX_RETRIES` and `slot` is given by the configuration
  variable `YGGDRASIL_RABBITMQ_SLOT_SIZE` (defaults to `100` ms).
  """
  app_env :yggdrasil_rabbitmq_max_retries, :yggdrasil, :max_retries,
    default: 12,
    domain: :rabbitmq

  @doc """
  RabbitMQ slot size for the backoff algorithm. Defaults to `100`.

  It looks for the value following this order.

    1. The OS environment variable `$YGGDRASIL_RABBITMQ_SLOT_SIZE`.
    2. The configuration file.
    3. The default value `100`.

  If slot sizes is defined using a namespace, then the name of the OS
  variable should be `$<NAMESPACE>_YGGDRASIL_RABBITMQ_SLOT_SIZE` where
  `NAMESPACE` is the snake case version of the actual namespace e.g.
  `MyApp.Namespace` would be `MYAPP_NAMESPACE`.

  ```
  config :yggdrasil, <NAMESPACE>,
    rabbitmq: [slot_size: 100]
  ```
  """
  app_env :yggdrasil_rabbitmq_slot_size, :yggdrasil, :slot_size,
    default: 100,
    domain: :rabbitmq

  @doc """
  RabbitMQ subscriber options. They are options for `:poolboy`. Defaults to
  `[size: 5, max_overflow: 10].`

  ```
  config :yggdrasil, <NAMESPACE>
    rabbitmq: [subscriber_options: [size: 5, max_overflow: 10]]
  ```
  """
  app_env :yggdrasil_rabbitmq_subscriber_options, :yggdrasil, :subscriber_options,
    default: [size: 5, max_overflow: 10],
    domain: :rabbitmq
end
