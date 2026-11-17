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

### Changed

- `ApiError#code` gives the `code` field of the error body, for example `idempotency_key_in_progress` or `internal_error`.
- `ConflictError#in_progress?` is true for the code `idempotency_key_in_progress`.
- The client retries a 409 with the code `idempotency_key_in_progress` when the request has an `idempotency_key`. It uses the normal backoff. It does not retry the other 409 codes.
- `RateLimitError#limit` gives the `X-RateLimit-Limit` header.
- If an error body has a `code` and no `message`, the error message gives the status and the code.
- `media.list` reads the flat Laravel paginator of `GET /v1/media`. `meta` holds the page fields, and `next_page` reads `next_page_url`.
- A template layer with no override returns `available_modifications` as an empty map, not as an empty Array.
- `signed_url` raises `ArgumentError` for `format: "jpeg"` with `transparent`. The instance returns HTTP 400 for this pair.
- The test fixtures use the response shapes of the API at commit `4d008a5`. The screenshot list items have `image_url`. The snaps have `width` and `height`. The batches have all the progress fields.
- The README describes the 403 of `POST /v1/snaps`, the 409 codes, the `internal_error` code of a 500, and the screenshot id fields.
