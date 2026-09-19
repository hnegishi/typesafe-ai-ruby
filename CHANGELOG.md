# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-09-19

Initial release.

- `TypeSafe::Client#system_one` and `client.models.list` for the System One API.
- `TypeSafe::Noul`, `Choice` and `Score` questions with typed answers.
- Configuration from options or `TYPESAFE_*` environment variables.
- Retries with backoff and `Retry-After`, keep-alive connections, logging and instrumentation hooks.
- RBS signatures.

[Unreleased]: https://github.com/hnegishi/typesafe-ai-ruby/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/hnegishi/typesafe-ai-ruby/releases/tag/v0.1.0
