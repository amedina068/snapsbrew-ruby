# Changelog

All notable changes to this project are in this file.

The format is [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-11-25

The gem adopts the OpenAPI spec of the app at `docs/api/openapi.yaml` (app PRs 93 and 95).

### Added

- `templates.preview(uuid, variants:)` returns the watermarked HTML preview of a template, the same as in the other SDKs.
- `templates.set_tags(uuid, tag_ids)` replaces the tags of a template.
- `WebhookVerificationError#reason` can be `:payload`: the signature is valid, but the body is not a JSON object.
- The webhook vectors have the expected `reason` of each invalid case and the `delivery_id` of each valid case.
- The gem is under the MIT License. The gemspec has `license = "MIT"`.
- `Snapsbrew::Webhook.verify` verifies the `X-Snapsbrew-Signature` and `X-Snapsbrew-Timestamp` headers of a webhook in constant time. It returns the decoded event, or raises `Snapsbrew::WebhookVerificationError` with the `reason` `:signature` or `:timestamp`. The tolerance is 300 seconds by default.
- The verified event has `delivery_id`, the value of the `X-Snapsbrew-Delivery` header. Use it to ignore a duplicate delivery.
- `Snapsbrew::Webhook::EVENTS` lists the events, with `snap.failed`.
- `Snapsbrew::Webhook.sign` signs a body, for the tests of your webhook controller.
- `config.webhook_secret`, with the fallback `SNAPSBREW_WEBHOOK_SECRET` and the Rails credential `snapsbrew.webhook_secret`.
- `templates.create` and `templates.update` accept `groups`, the editor layer groups.
- `ConflictError#current_revision` and `ConflictError#current_document` give the stored editor document after an `editor_document_conflict`.
- `NotFoundError#available` gives the valid keys after a 404 from `guides.platform` or `guides.purpose`.
- `Snapsbrew.documents` for the v2 editor document of a template: `find`, `replace`, `apply` and `preflight`. A write conflict raises a `ConflictError` with `current_revision` and `current_document`. An operation error raises a `ValidationError` with a `code` and no field errors. The client does not retry a write after a server error.
- `Snapsbrew.forms.submit` sends the layers of an embedded form to its signed submit URL. It sends text as a field and an image as a file. It returns one snap for a template form, and an Array of snaps for a collection form. A 429 has the code `rate_limited`.
- `Client#request` accepts a signed absolute URL. It sends no API token to such a URL.

### Changed

- `templates.destroy` and each other `DELETE` or `PUT` request are retried after a 5xx or a timeout, the same as in the other SDKs. `documents.replace` is still never retried after a 5xx or a timeout, because a repeat gets a 409.
- `Webhook.verify` reads the headers without case, and takes the first value of a list.
- `Webhook.verify` accepts an uppercase hex signature. It changes the signature to lowercase before the constant-time compare.
- A missing or malformed `X-Snapsbrew-Timestamp` header raises the reason `:timestamp`. It was `:signature`.
- An empty `X-Snapsbrew-Delivery` header gives a `nil` delivery ID.
- Invalid JSON after a valid signature raises `WebhookVerificationError` with the reason `:payload`. It was `JSON::ParserError`.

### Removed

- Breaking: `tags.sync(template:, tag_ids:)`. Use `templates.set_tags(uuid, tag_ids)`.

- `media.upload` also accepts a `Pathname`.
- An error body with an empty `message`, for example the 404 of an embedded form with a bad signature, gives the message `Snapsbrew returned HTTP 404`.

- The version is `0.2.0`.
- The README documents the 403 `Invalid ability provided.` of each endpoint, the 422 of a cursor that is not valid, the 422 of an editor operation, and the 404 message of a missing record.
- The README documents `last_error` as a code: `render_failed`, `webhook_redirect_refused`, `webhook_unreachable` or `webhook_http_<status>`. A batch item has `render_failed` only.
- The README documents the upload rules of `media.upload` and the size limits of `screenshots.create`. The gem does not check them.
- The README tells that a signed URL accepts each active signing key of the company, and that `templates.destroy` also removes the snaps, images, versions and forms of the template.
- The README no longer says that a snap costs a credit. The instance keeps a usage log with no balance.
- The README links to the SDK overview at <https://snapsbrew.com/docs/sdks/overview>.
- The install generator shows `webhook_secret` in the credentials example.

## [0.1.0] - Not published

Version 0.1.0 was not published. Release 0.2.0 contains these changes.

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
- A media record has nine fields: `id`, `uuid`, `name`, `file_name`, `mime_type`, `size`, `original_url`, `src` and `created_at`. The API no longer sends `model_type`, `collection_name`, `preview_url`, `updated_at` or the other internal fields. A call to a removed field as a method raises `NoMethodError`, and `record[:field]` gives `nil`. The media fixtures use the new shape.
- The `image_url` of a screenshot is `nil` when the screenshot has no image. The API sent an empty string before. The README tells you to check for `nil`.
- A 500 from `batches.create` raises `ServerError` with the code `internal_error`, the same as `snaps.create`.
