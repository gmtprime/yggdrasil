# Changelog for 4.1.1

## Highlights

## v4.1.1

### Bug fixes

  * Fixed channel defaults

### Enhancements

  * [`Yggdrasil`] Now `subscribe/1`, `unsubscribe/1` and `publish/3` can
  receive a map or a `Keyword` list as channel as well as the
  `Yggdrasil.Channel` struct.
  * Added Yggdrasil logo to documentation.
  * Added Yggdrasil Ethereum adapter to documentation.
  * Added Yggdrasil GraphQL adapter to documentation.

# Changelog for 4.1.0

## Highlights

## v4.1.0

### Bug fixes

  * Fixed connection messages. They weren't reliable.

### Enhancements

  * [`Yggdrasil.Subscriber.Adapter`] Simplified the subscriber adapter
  behaviour.
  * [`Yggdrasil.Subscriber.Manager`] Improved subscriber manager to distribute
  connection and disconnection messages from the adapters.

# Changelog for 4.0.0

## Highlights

## v4.0.0

### Enhancements

  * [`Yggdrasil.Adapter`] Added behaviour to add adapters easily.
  * [`Yggdrasil.Backend`] Added behaviour to add backends easily.
  * [`Yggdrasil.Transformer`] Improved the transformer behaviour.
  * [`:yggdrasil_redis`, `:yggdrasil_rabbitmq`, `:yggdrasil_postgres`]
  Separated Redis, RabbitMQ and PostgreSQL adapters to three other
  repositories. This makes Yggdrasil really agnostic.
  * Updated the code to follow the new Supervisor child specs.

# Changelog for 3.3.4

## Highlights

## v3.3.4

### Bug fixes

  * Fixed bug in Redis and Postgres adapters that didn't publish the
    disconnection message correctly. Closes #6 and #7.
  * Improved disconnection handling.

### Enhancements

  * [`Yggdrasil.Subscriber.Adapter.Postgres`] Exponential backoff on connection
  retries.

# Changelog for 3.3.3

## Highlights

## v3.3.3

### Enhancements

  * [`Yggdrasil.Subscriber.Adapter.RabbitMQ`] Exponential backoff on connection
  retries.
  * Improved disconnection handling.

# Changelog for v3.3.0

## Highlights

## v3.3.0

### Bug fixes

  * [`Yggdrasil.Subscriber.Adapter.RabbitMQ`] Now properly closes the open
    channels when the client unsubscribes.

### Enhancements

  * [`Yggdrasil.Distributor`] Now the subscriptions to channels are managed by
  the subscription process tree instead of a process outside of this tree.
  * [`Yggdrasil`] On unsubscription or disconnection, a new message is sent to
  subscribers: `{:Y_DISCONNECTED, Yggdrasil.Channel.t()}`.
  * Improved documentation.
  * Updated dependencies.

### Changes

  * Added `docker-compose.yml` file that starts a PostgreSQL database, a
  RabbitMQ server and a Redis server (useful for testing).

# Changelog for v3.2.1

## Highlights

## v3.2.1

### Bug fixes

  * Consistency between versions in the documentation and the code.

### Enhancements

  * [`Yggdrasil.Subscriber.Adapter.RabbitMQ`] For the adapter configuration,
  the `host` is now set as `hostname`.
  * [`Yggdrasil.Subscriber.Adapter.Redis`] For the adapter configuration, the
  `host` is now set as `hostname`.
  * [`Yggdrasil.Settings`] Added this module to handle the application
  configuration using `Skogsra`. This allows Yggdrasil to be configured by
  using OS environment variables. Also, this module has all the configuration
  settings properly documented.

### Changes

  * `.travis.yml` was simplified by just setting an environment variable during
  the tests.
