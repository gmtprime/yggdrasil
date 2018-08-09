# Changelog for 3.3.4

## Highlights

## v3.3.4

### Enhancements

  * [Yggdrasil.Subscriber.Adapter.Postgres] Exponential backoff on connection
  retries.

### Bug fixes
  * Fixed bug in Redis and Postgres adapters that didn't publish the
    disconnection message correctly. Closes #6 and #7.
  * Improved disconnection handling.

# Changelog for 3.3.3

## Highlights

## v3.3.3

### Enhancements

  * [Yggdrasil.Subscriber.Adapter.RabbitMQ] Exponential backoff on connection
  retries.
  * Improved disconnection handling.

# Changelog for v3.3.0

## Highlights

## v3.3.0

### Bug fixes

  * [Yggdrasil.Subscriber.Adapter.RabbitMQ] Now properly closes the open
    channels when the client unsubscribes.

### Enhancements

  * [Yggdrasil.Distributor] Now the subscriptions to channels are managed by
  the subscription process tree instead of a process outside of this tree.
  * [Yggdrasil] On unsubscription or disconnection, a new message is sent to
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

  * [Yggdrasil.Subscriber.Adapter.RabbitMQ] For the adapter configuration, the
  `host` is now set as `hostname`.
  * [Yggdrasil.Subscriber.Adapter.Redis] For the adapter configuration, the
  `host` is now set as `hostname`.
  * [Yggdrasil.Settings] Added this module to handle the application
    configuration using `Skogsra`. This allows Yggdrasil to be configured by
    using OS environment variables. Also, this module has all the configuration
    settings properly documented.

### Changes

  * `.travis.yml` was simplified by just setting an environment variable during
  the tests.
