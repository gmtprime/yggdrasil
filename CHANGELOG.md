# Changelog for v3.2.1

## Highlights

## v3.2.1

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

### Bug fixes

  * Consistency between versions in the documentation and the code.
