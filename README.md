# Snapsbrew for Ruby

A Ruby client for the Snapsbrew image API, with a Rails integration.

Snapsbrew renders images ("snaps") from templates. You run your own Snapsbrew instance, so each client talks to the instance URL that you give it. The gem uses the Ruby standard library only. It has no runtime dependencies and sends no telemetry.

```ruby
Snapsbrew.snaps.create(template: "044ec825-...", variants: { title: "Hello", cover: "https://example.com/cover.jpg" })
Snapsbrew.signed_url(template: "044ec825-...", title: "Hello")
```

## Install

Add the gem to your Gemfile:

```ruby
gem "snapsbrew", github: "amedina068/snapsbrew-ruby"
```

Then run `bundle install`.

The gem is not on RubyGems yet.

## Quick start

1. Get an API token with the `api_requests` ability from your Snapsbrew instance.
2. Configure the client:

   ```ruby
   require "snapsbrew"

   Snapsbrew.configure do |config|
     config.url   = "https://snaps.example.com"
     config.token = ENV["SNAPSBREW_TOKEN"]
   end
   ```

3. Find a template and render a snap:

   ```ruby
   template = Snapsbrew.templates.first
   template.layers.map(&:layer)   # => ["title", "cover"]

   html = Snapsbrew.snaps.preview(template: template.uuid, variants: { title: "Hello" })
   snap = Snapsbrew.snaps.create(template: template.uuid, variants: { title: "Hello" })
   snap.media_url                 # => "https://snaps.example.com/storage/snaps/9f1c2d3e.png"
   ```

A preview is free and returns watermarked HTML. A snap costs one credit.

## Configuration

| Setting       | Default | Environment variable    | Description |
|---------------|---------|-------------------------|-------------|
| `url`         | none    | `SNAPSBREW_URL`         | The URL of your instance, for example `https://snaps.example.com`. |
| `token`       | none    | `SNAPSBREW_TOKEN`       | The API token. The client sends it as `Authorization: Bearer`. |
| `signing_key` | none    | `SNAPSBREW_SIGNING_KEY` | The key for signed URLs. Only signed URLs need it. |
| `timeout`     | `60`    |                         | The seconds to wait for a connection and for a response. |
| `max_retries` | `2`     |                         | The retries after a failed request. `0` turns retries off. |

If a setting is not configured, the gem reads the environment variable. In a Rails app, the gem also reads the Rails credentials (see [Rails](#rails)).

The API lives at `{url}/api`. You can give the `url` with or without `/api`.

`Snapsbrew.snaps` and the other module methods use one default client. To talk to more than one instance, make a client for each instance:

```ruby
client = Snapsbrew::Client.new(url: "https://snaps.example.com", token: ENV["SNAPSBREW_TOKEN"])
client.templates.list
```

## Usage

Each call returns a `Snapsbrew::Record`. Read a field as a method or with `[]`:

```ruby
account = Snapsbrew.account
account.email       # => "dev@example.com"
account[:company]   # => "Analytical Engines"
account.to_h        # => {"email" => "dev@example.com", ...}
```

### Variants

Variants change the layers of a template. Give a Hash that maps each layer key to a value:

| Value                    | Override |
|--------------------------|----------|
| A String or a number     | `text` |
| An `http` or `https` URL | `image_url` |
| `false` or `nil`         | `hidden: true` |
| A Hash                   | The override that you name, for example `{ background_color: "#f0573f" }` |

```ruby
Snapsbrew.snaps.create(template: id, variants: {
  title:  "Hello",
  cover:  "https://example.com/cover.jpg",
  badge:  false,
  bg:     { background_color: "#f0573f" },
  footer: { text: "https://snapsbrew.com" }
})
```

A text that is a URL becomes an image. To show a URL as text, give `{ text: "https://..." }`.

You can also give the array that the API reads:

```ruby
Snapsbrew.snaps.create(template: id, variants: [
  { layer: "title", text: "Hello" },
  { layer: "cover", image_url: "https://example.com/cover.jpg" }
])
```

### Snaps

```ruby
snap  = Snapsbrew.snaps.create(template: id, variants: { title: "Hello" })
snap  = Snapsbrew.snaps.create(template: id, format: "webp", transparent: true)
snap  = Snapsbrew.snaps.create(template: id, async: true, webhook_url: "https://example.com/hooks/snap")
snap  = Snapsbrew.snaps.create(template: id, idempotency_key: "order-1234")
snaps = Snapsbrew.snaps.create(collection: collection_id)   # An Array, one snap for each template

html = Snapsbrew.snaps.preview(template: id, variants: { title: "Hello" })
```

The API renders the published version of a template. Publish a template after you change it.

### Batches

A batch renders up to 100 snaps from one template in the background.

```ruby
batch = Snapsbrew.batches.create(template: id, title: "October launch", items: [
  { identifier: "row-1", variants: { title: "Hello" } },
  { identifier: "row-2", variants: { title: "World" } }
])

batch = Snapsbrew.batches.find(batch.uuid)
batch.status                        # => "completed"
batch.items.filter_map(&:media_url)

Snapsbrew.batches.cancel(batch.uuid)
```

Read a batch about every 5 seconds. Stop when the status is `completed`, `failed` or `canceled`.

### Templates

```ruby
page = Snapsbrew.templates.list           # One page
page = page.next_page if page.next_page?
Snapsbrew.templates.each { |template| }   # Every template, page after page

Snapsbrew.templates.find(id)
Snapsbrew.templates.sizes
Snapsbrew.templates.create(title: "Launch card", size: "open_graph")
Snapsbrew.templates.update(id, title: "Launch card", width: 1080, height: 1080)
Snapsbrew.templates.publish(id)
Snapsbrew.templates.destroy(id)
```

Each layer of a template has `layer` and `available_modifications`. `available_modifications` maps each override to its current value. A layer with no override has an empty map.

To create or update the layers, give layer objects:

```ruby
Snapsbrew.templates.create(title: "Launch card", size: "open_graph", layers: [
  { key: "title", type: "text", properties: [ { name: "textContent", value: "Hello" } ] }
])
```

`templates.update` cannot change a template that uses the v2 editor document. It raises a `ConflictError` with the code `legacy_edit_rejected_for_v2`.

### Screenshots, media and tags

```ruby
Snapsbrew.screenshots.create(url: "https://example.com", width: 1280, height: 720)
Snapsbrew.screenshots.find(uuid)
Snapsbrew.screenshots.each { |screenshot| screenshot.image_url }

Snapsbrew.media.upload("logo.png")        # A path, a File, or an uploaded file from a form
Snapsbrew.media.each { |image| image.src }
Snapsbrew.media.list(page: 2).meta.total  # The page fields of the Laravel paginator

Snapsbrew.tags.list(search: "launch")
Snapsbrew.tags.create(name: "Launch")
Snapsbrew.tags.sync(template: id, tag_ids: [ 1, 2 ])
```

A screenshot from `create` and `find` has its id in `id`. A screenshot from `each` and `list` has the same value in `uuid`.

Use the `src` of a media image as an `image_url` variant.

### Guides

The guides are static reference catalogs. Their content is the same for every account, so you can cache it.

```ruby
Snapsbrew.guides.design
Snapsbrew.guides.layers
Snapsbrew.guides.variant_properties
Snapsbrew.guides.editor_document
Snapsbrew.guides.platforms
Snapsbrew.guides.platform(:instagram)
Snapsbrew.guides.purposes
Snapsbrew.guides.purpose(:link_preview)
```

## Signed URLs

A signed URL renders a snap from a plain `<img src>` or an `og:image` tag. The browser loads the image with no API call. The instance caches each URL, so the same URL renders one time only.

```ruby
Snapsbrew.signed_url(template: id, title: "Hello", cover: "https://example.com/cover.jpg")
# => "https://snaps.example.com/signed-url/image.jpg?template_id=...&variants=...&signature=..."

Snapsbrew.signed_url(template: id, variants: [ { layer: "title", text: "Hello" } ], format: "webp")
```

Each keyword other than `template`, `variants`, `format` and `transparent` is a layer. If a layer has one of these four names, give it in `variants`.

The instance accepts `png`, `jpeg` and `webp` as `format`. For each other value, it renders a PNG.

`transparent: true` is valid for `png` and `webp`. A JPEG cannot be transparent, so the builder raises `ArgumentError` for this pair.

If the signature or the template is not valid, the instance returns a placeholder image with status 200. The `<img>` shows no error.

**WARNING:** Keep the signing key on the server. Do not build signed URLs in a browser. A person with the key can render images on your account.

The signature is the HMAC-SHA256 hex digest of the canonical string, with the signing key. The canonical string has all the query parameters except `signature`, sorted by key, joined as `key=value` with `&`. `variants` is the standard Base64 of the JSON array.

## Rails

The gem has a Railtie. Rails loads it when the gem is in your Gemfile.

### Credentials

Put the settings in the credentials:

```sh
bin/rails credentials:edit
```

```yaml
snapsbrew:
  url: https://snaps.example.com
  token: your-api-token
  signing_key: your-signing-key
```

The Railtie reads `Rails.application.credentials.snapsbrew` before the initializers of your app. A `Snapsbrew.configure` call in an initializer wins.

### Generator

```sh
bin/rails generate snapsbrew:install
```

The generator writes `config/initializers/snapsbrew.rb`.

### View helpers

`snapsbrew_image_tag` builds a signed URL and wraps `image_tag`. Each keyword other than `template`, `alt` and `html` is a layer. Give HTML attributes with `html:`.

```erb
<%= snapsbrew_image_tag template: "044ec825-...", alt: @post.title,
      title: @post.title, cover: @post.cover_url, html: { class: "cover", loading: "lazy" } %>
```

`snapsbrew_og_image_tag` renders the `og:image` meta tag:

```erb
<% content_for :head do %>
  <%= snapsbrew_og_image_tag template: "044ec825-...", title: @post.title %>
<% end %>
```

## Errors

Each error is a `Snapsbrew::Error`.

| Error                            | Cause |
|----------------------------------|-------|
| `Snapsbrew::ConfigurationError`  | A setting is missing, for example the `url` or the `token`. |
| `Snapsbrew::ConnectionError`     | The connection failed or timed out. The original error is in `cause`. |
| `Snapsbrew::AuthenticationError` | 401. The token is missing or not valid. |
| `Snapsbrew::AuthorizationError`  | 403. The token does not have the `api_requests` ability, or a permission check refused the request. |
| `Snapsbrew::NotFoundError`       | 404. |
| `Snapsbrew::ConflictError`       | 409. `code` gives the cause. See [Conflicts](#conflicts). |
| `Snapsbrew::ValidationError`     | 422. `errors` has the field errors. A `template_id` that does not exist in your company is a 422, not a 404. |
| `Snapsbrew::RateLimitError`      | 429. `retry_after` has the seconds to wait. `limit` has the requests that the endpoint allows in one minute. |
| `Snapsbrew::ServerError`         | 5xx. If `snaps.create` fails on the server, `code` is `internal_error`. |
| `Snapsbrew::ApiError`            | Each other status. It is also the parent of the HTTP errors above. |

Each `ApiError` has `status`, `body`, `message`, `code` and `request_id`. The `code` is the `code` field of the body, or `nil`. The `request_id` is the `X-Request-Uuid` header. Give it when you ask for support.

```ruby
begin
  Snapsbrew.snaps.create(template: id, variants: { cover: "http://10.0.0.1/a.jpg" })
rescue Snapsbrew::ValidationError => error
  error.errors   # => {"variants.0.image_url" => ["..."]}
end
```

### Conflicts

A `ConflictError` has one of these codes:

| `code`                             | Cause | Retry |
|------------------------------------|-------|-------|
| `idempotency_key_in_progress`      | Another request with the same `idempotency_key` is in progress. | The client retries it. A repeat with the same key is safe. |
| `idempotency_key_belongs_to_snap`  | A single snap owns the key, so `batches.create` cannot use it. | No. Send a new key. |
| `idempotency_key_belongs_to_batch` | A batch owns the key, so `snaps.create` cannot use it. | No. Send a new key. |
| `legacy_edit_rejected_for_v2`      | The template uses the v2 editor document, so `templates.update` cannot change it. | No. |

`error.in_progress?` is true for `idempotency_key_in_progress`.

## Retries

The client retries a failed request up to `max_retries` times:

- It retries a 429 for each request. It waits for the seconds in `Retry-After`. If `Retry-After` is more than 60 seconds, it does not retry.
- It retries a 5xx for an idempotent request only.
- It retries a 409 with the code `idempotency_key_in_progress` for a request with an `idempotency_key`. It does not retry the other 409 codes.
- It retries a connection error that occurs before the request reaches the server, for each request.
- It retries a connection error that can occur after the server received the request, for example a read timeout, for an idempotent request only.

Between two attempts, the client waits with exponential backoff and jitter. The wait is about 0.5, 1, 2 and 4 seconds, to a maximum of 8 seconds.

These requests are idempotent: each `GET`, `templates.publish`, `batches.cancel`, `tags.sync`, and `snaps.create` or `batches.create` with an `idempotency_key`. To make a snap safe to retry, give an `idempotency_key`:

```ruby
Snapsbrew.snaps.create(template: id, variants: { title: "Hello" }, idempotency_key: "order-1234")
```

## Supported versions

- Ruby 3.2, 3.3 and 3.4
- Rails 7.2, 8.0 and 8.1 (optional)

## Not in this version

- The editor document endpoints (`/v1/templates/{uuid}/document`)
- The embedded form endpoint (`/v1/embedded-forms/{uuid}`)

## Development

```sh
bundle install
bin/rake            # Unit tests, Rails tests and integration tests
bin/rubocop         # Lint
bin/rake rbs        # Validate the RBS signatures in sig/
```

The integration tests run only when `SNAPSBREW_TEST_URL` and `SNAPSBREW_TEST_TOKEN` are set. They read the account and the templates, and they make one free preview.

To test with a different Rails version, set `RAILS_VERSION`, for example `RAILS_VERSION="~> 7.2.0" bundle update rails`.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before you open a pull request.
