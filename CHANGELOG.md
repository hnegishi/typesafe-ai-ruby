# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Project scaffold: gemspec, test and lint setup, CI matrix for Ruby 3.1 to 3.4.
- `TypeSafe::Client#system_one` and `#models.list` against `POST /v1/systemone` and `GET /v1/models`.
- `TypeSafe::Noul`, `Choice` and `Score` question objects, plus `TypeSafe.noul` / `.choice` / `.score` helpers.
  Raw Hash questions are passed through untouched.
- Typed answers (`NoulAnswer`, `ChoiceAnswer`, `ScoreAnswer`) grouped by `nouls` / `choices` / `scores`.
- Configuration from options or `TYPESAFE_*` environment variables, `TypeSafe.configure` and `TypeSafe.client`.
- Error hierarchy mirroring the official SDKs, including `RateLimitError#retry_after` and
  `APIResponseValidationError#field_path`.
- Net::HTTP transport with a pluggable `transport:` option.
