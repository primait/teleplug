# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

-

---

## [1.1.3] - 2023-04-04

### Changed

- Fix versioning of `telemetry` dependency

## [1.1.2] - 2023-03-23

### Added

- Set span status to error if the returned http status code is 5xx

## [1.1.1] - 2023-03-09

### Added

- Usage of the `opentelemetry_semantic_conversion` auto-generated library to
  ensure proper conventions are followed

### Changed

- Changed client attributes to proper server attributes
  - `"net.peer.ip"` is now `"net.sock.peer.addr"`
  - `"net.peer.port"` is now `"net.sock.peer.port"`

### Removed

- `"http.host"` attribute as it is non standard, and already covered by
  `"net.host.name"`

## [1.1.0] - 2022-09-21

### Changed

- Teleplug does not set opentelemetry-related Logger metadata anymore, because
  The OpenTelemetry API/SDK itself
  [does that automatically since 1.1.0](https://github.com/open-telemetry/opentelemetry-erlang/pull/394).
  If you're upgrading to Teleplug 1.1.0, it is therefore recommended to also
  upgrade to OpenTelemetry API 1.1.0

[Unreleased]: https://github.com/primait/teleplug/compare/1.1.3...HEAD
[1.1.3]: https://github.com/primait/teleplug/compare/1.1.2...1.1.3
[1.1.2]: https://github.com/primait/teleplug/compare/1.1.1...1.1.2
[1.1.1]: https://github.com/primait/teleplug/compare/1.1.0...1.1.1
[1.1.0]: https://github.com/primait/teleplug/releases/tag/1.1.0
