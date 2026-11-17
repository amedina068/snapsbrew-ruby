# Changelog

All notable changes to this project are in this file.

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - Unreleased

### Added

- `Snapsbrew::Client` for one Snapsbrew instance, with a bearer token, a timeout and retries.
- `Snapsbrew.configure`, with fallbacks to `SNAPSBREW_URL`, `SNAPSBREW_TOKEN` and `SNAPSBREW_SIGNING_KEY`.
- Resources: account, guides, templates, snaps, batches, screenshots, media and tags.
- Variants as a Hash of layers or as the array of the API.
- `Snapsbrew.signed_url` to build signed image URLs.
- Typed errors for 401, 403, 404, 409, 422, 429, 5xx and connection failures.
- Retries with exponential backoff and jitter. The client obeys `Retry-After`.
- Rails integration: a Railtie that reads the credentials, the `snapsbrew_image_tag` and `snapsbrew_og_image_tag` helpers, and the `snapsbrew:install` generator.
- RBS signatures in `sig/`.
