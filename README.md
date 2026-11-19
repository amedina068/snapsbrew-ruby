# Snapsbrew for Ruby

A Ruby client for the Snapsbrew image API, with a Rails integration.

Snapsbrew renders images ("snaps") from templates. You run your own Snapsbrew instance, so each client talks to the instance URL that you give it. The gem uses the Ruby standard library only. It has no runtime dependencies and sends no telemetry.

```ruby
Snapsbrew.snaps.create(template: "044ec825-...", variants: { title: "Hello", cover: "https://example.com/cover.jpg" })
Snapsbrew.signed_url(template: "044ec825-...", title: "Hello")
```

The SDK overview for all languages is at <https://snapsbrew.com/docs/sdks/overview>.

## Install

Add the gem to your Gemfile:

```ruby
gem "snapsbrew", github: "amedina068/snapsbrew-ruby"
```

Then run `bundle install`.

The gem is not on RubyGems yet. Bundler installs it from the `main` branch of the Git repository. The repository is private, so Git must have access to GitHub, for example through `gh auth setup-git`.

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

A preview returns watermarked HTML and stores no snap. `snaps.create` renders the final image.

## Configuration

| Setting          | Default | Environment variable       | Description |
|------------------|---------|----------------------------|-------------|
| `url`            | none    | `SNAPSBREW_URL`            | The URL of your instance, for example `https://snaps.example.com`. |
| `token`          | none    | `SNAPSBREW_TOKEN`          | The API token. The client sends it as `Authorization: Bearer`. |
| `signing_key`    | none    | `SNAPSBREW_SIGNING_KEY`    | The key for signed URLs. Only signed URLs need it. |
| `webhook_secret` | none    | `SNAPSBREW_WEBHOOK_SECRET` | The secret for webhook signatures. Only `Snapsbrew::Webhook.verify` needs it. |
| `timeout`        | `60`    |                            | The seconds to wait for a connection and for a response. |
| `max_retries`    | `2`     |                            | The retries after a failed request. `0` turns retries off. |

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

An async snap posts a webhook to `webhook_url` when it is done. See [Webhooks](#webhooks).

`last_error` is a code, not a message. It is `nil` when the snap has no error:

| `last_error`               | Cause |
|----------------------------|-------|
| `render_failed`            | The render failed. The `status` is `failed`. |
| `webhook_redirect_refused` | The webhook receiver returned a redirect. The client does not follow a redirect. |
| `webhook_unreachable`      | The webhook receiver did not answer. |
| `webhook_http_<status>`    | The webhook receiver returned this HTTP status, for example `webhook_http_500`. |

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

The `last_error` of a failed item is the code `render_failed`. It never holds the message of the renderer.

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

To create or update the editor layer groups, give `groups`. Each group needs an `id`. `name`, `visible`, `collapsed` and `order` are optional. To remove the groups, give an empty list:

```ruby
Snapsbrew.templates.update(id, title: "Launch card", groups: [ { id: "header", name: "Header", order: 0 } ])
Snapsbrew.templates.update(id, title: "Launch card", groups: [])
```

`templates.update` changes only the fields that you give. It cannot change a template that uses the v2 editor document. It raises a `ConflictError` with the code `legacy_edit_rejected_for_v2`. Use [editor documents](#editor-documents) for these templates.

`templates.destroy` also removes the snaps, images, versions and forms of the template.

### Editor documents

The editor document is the v2 draft of a template: its layers, its groups and each design property. A snap renders from the published version of the template, not from the draft.

Each write is a compare-and-swap:

1. Read the document. Keep its `revision`.
2. Send the write with this revision.
3. If another write changed the document first, the write raises a `ConflictError`. Make the change again on `current_document`, and send it with `current_revision`.
4. After the last write, publish the template.

```ruby
draft = Snapsbrew.documents.find(id)
draft.revision            # => 4
draft.document.layers     # => [#<Snapsbrew::Record ...>]

Snapsbrew.documents.apply(id, revision: draft.revision, operations: [
  { operation: "set_layer_property", layer_key: "headline", property: "fontWeight", value: 700 },
  { operation: "set_layer_type", layer_key: "logo", type: "image" }
])

Snapsbrew.documents.replace(id, revision: 5, document: { version: 2, layers: [], groups: [] })

Snapsbrew.documents.preflight(id).issues   # => [#<Snapsbrew::Record {"code" => "image_asset_missing", ...}>]
Snapsbrew.templates.publish(id)
```

- `find` gives the document and its revision. A template with no draft has a `nil` document and the revision `0`.
- `apply` applies 1 to 100 operations: `set_layer_property` and `set_layer_type`. They apply together, or none applies. It changes only the properties that the operations name.
- `replace` replaces the whole document. A layer or a property that you leave out is removed.
- `preflight` lists the known problems of the stored draft. An empty `issues` list means that the known checks pass. It does not prove that the render looks correct.
- `Snapsbrew.guides.editor_document` gives the properties and limits that both writes accept.

The client does not retry `apply` or `replace` after a server error, because a write that reached the server changes the revision.

### Embedded forms

An embedded form renders a snap from the values that a visitor sends. The form renders on the account of its owner, so a submit needs no token. Copy the submit URL of the form from your instance. The URL carries its own signature.

```ruby
snap = Snapsbrew.forms.submit(submit_url, headline: "Hello", photo: params[:photo])
snap.media_url

snaps = Snapsbrew.forms.submit(collection_submit_url, "141e8454-...__headline" => "Hello")   # An Array
```

- Give text as a String. Give an image as a File, a `Pathname`, or an uploaded file from a form.
- A template form uses the layer key, for example `headline`. A collection form uses `{template uuid}__{layer key}` and returns an Array of snaps.
- The form accepts only the layers that its configuration names. It ignores each other layer.
- An image is a JPG, PNG, GIF, WebP or BMP file of 10 MB or less.
- The client never sends the API token to the submit URL.
- If the signature is not valid, or the form does not exist, `submit` raises a `NotFoundError`.
- If one IP address or one form sends too many submissions in one minute, `submit` raises a `RateLimitError` with the code `rate_limited`.

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

The `width` and `height` of a screenshot are 1 to 4000 pixels. The default viewport is 1330 x 780.

`media.upload` accepts JPG, JPEG, PNG, GIF, WebP and BMP files of 10 MB or less. It does not accept SVG.

The gem does not check these limits. The instance checks them and returns a `ValidationError`.

A screenshot from `create` and `find` has its id in `id`. A screenshot from `each` and `list` has the same value in `uuid`. The `image_url` of a screenshot is `nil` when the screenshot has no image.

Use the `src` of a media image as an `image_url` variant. A media image has these fields and no other field: `id`, `uuid`, `name`, `file_name`, `mime_type`, `size`, `original_url`, `src` and `created_at`.

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

For an unknown key, `platform` and `purpose` raise a `NotFoundError`. Its `available` gives the valid keys:

```ruby
begin
  Snapsbrew.guides.platform(:myspace)
rescue Snapsbrew::NotFoundError => error
  error.available   # => ["instagram", "facebook", "x", ...]
end
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

The instance accepts a signature from each active signing key of the company that owns the template.

If the signature or the template is not valid, the instance returns a placeholder image with status 200. The `<img>` shows no error.

The instance returns 400 for variants that are not valid, and 429 when one IP address sends too many requests in one minute. The `<img>` shows no error for these statuses either.

The instance reserves the parameters `identifier` and `api_log_uuid`. The builder sends only `template_id`, `variants`, `format`, `transparent` and `signature`, so it never sends a reserved parameter.

**WARNING:** Keep the signing key on the server. Do not build signed URLs in a browser. A person with the key can render images on your account.

The signature is the HMAC-SHA256 hex digest of the canonical string, with the signing key. The canonical string has all the query parameters except `signature`, sorted by key, joined as `key=value` with `&`. `variants` is the standard Base64 of the JSON array.

## Webhooks

An async snap and a batch post a webhook to their `webhook_url`. Snapsbrew signs each webhook. `Snapsbrew::Webhook.verify` verifies the signature and the timestamp, and returns the decoded event.

Each company has one webhook secret. Find it under **Account > Developers** on your instance. A secret starts with `whsec_`.

Verify webhooks on the server only. Never put the webhook secret in browser code.

```ruby
class SnapsbrewWebhooksController < ActionController::API
  def create
    event = Snapsbrew::Webhook.verify(request.raw_post, request.headers)
    return head(:ok) if WebhookDelivery.exists?(delivery_id: event.delivery_id)

    case event.event
    when "snap.completed" then Cover.attach(event.snap.id, event.snap.media_url)
    when "snap.failed"    then Cover.fail(event.snap.id, event.snap.last_error)
    end

    WebhookDelivery.create!(delivery_id: event.delivery_id)
    head :ok
  rescue Snapsbrew::WebhookVerificationError
    head :bad_request
  end
end
```

- Give the raw body, byte for byte. Do not parse the JSON and encode it again. Snapsbrew escapes `/` as `\/` and each non-ASCII character as `\uXXXX`, so a new encoding gives other bytes.
- `headers` can be the Rails `request.headers`, a Rack env, or a Hash.
- The secret comes from `config.webhook_secret`. To give it directly, pass `secret: "whsec_..."`.
- The timestamp must be 300 seconds or less before or after the current time. To change this limit, pass `tolerance: 600`.
- Each problem raises `Snapsbrew::WebhookVerificationError`. Its `reason` is `:signature` or `:timestamp`.
- `event.delivery_id` is the `X-Snapsbrew-Delivery` header. All attempts of one delivery have the same value. Use it to ignore a duplicate.

The events are in `Snapsbrew::Webhook::EVENTS`:

| `event`                 | Body |
|-------------------------|------|
| `snap.completed`        | `snap`, the same fields as `snaps.create`. |
| `snap.failed`           | `snap` with `status: "failed"`, `last_error: "render_failed"` and `media_url: ""`. |
| `snap-import.completed` | `import` with the progress fields of a batch, and `template`. |
| `snap-import.failed`    | The same fields as `snap-import.completed`. |
| `snap-import.canceled`  | The same fields as `snap-import.completed`. |

The app can add events, so `verify` also accepts an event that is not in this list.

To test your own webhook controller, sign a body with `Snapsbrew::Webhook.sign`:

```ruby
body = JSON.generate(event: "snap.completed", snap: { id: "9f1c2d3e", media_url: "https://snaps.example.com/a.png" })
timestamp = Time.now.to_i
headers = {
  "X-Snapsbrew-Delivery" => SecureRandom.uuid,
  "X-Snapsbrew-Timestamp" => timestamp.to_s,
  "X-Snapsbrew-Signature" => Snapsbrew::Webhook.sign(timestamp, body, "whsec_test")
}

post snapsbrew_webhooks_path, params: body, headers: headers.merge("Content-Type" => "application/json")
```

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
  webhook_secret: whsec_your-webhook-secret
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

| Error                                 | Cause |
|---------------------------------------|-------|
| `Snapsbrew::ConfigurationError`       | A setting is missing, for example the `url` or the `token`. |
| `Snapsbrew::ConnectionError`          | The connection failed or timed out. The original error is in `cause`. |
| `Snapsbrew::AuthenticationError`      | 401. The token is missing or not valid. |
| `Snapsbrew::AuthorizationError`       | 403. The token does not have the `api_requests` ability (`Invalid ability provided.`), or a permission check refused the request. Each endpoint can return it. |
| `Snapsbrew::NotFoundError`            | 404. For an unknown guide key, `available` gives the valid keys. |
| `Snapsbrew::ConflictError`            | 409. `code` gives the cause. See [Conflicts](#conflicts). |
| `Snapsbrew::ValidationError`          | 422. `errors` has the field errors. A `template_id` that does not exist in your company is a 422, not a 404. A cursor that is not valid is also a 422. |
| `Snapsbrew::RateLimitError`           | 429. `retry_after` has the seconds to wait. `limit` has the requests that the endpoint allows in one minute. |
| `Snapsbrew::ServerError`              | 5xx. If `snaps.create` or `batches.create` fails on the server, `code` is `internal_error`. |
| `Snapsbrew::ApiError`                 | Each other status. It is also the parent of the HTTP errors above. |
| `Snapsbrew::WebhookVerificationError` | The webhook signature or timestamp is not valid. See [Webhooks](#webhooks). |

Each `ApiError` has `status`, `body`, `message`, `code` and `request_id`. The `code` is the `code` field of the body, or `nil`. The `request_id` is the `X-Request-Uuid` header. Give it when you ask for support.

```ruby
begin
  Snapsbrew.snaps.create(template: id, variants: { cover: "http://10.0.0.1/a.jpg" })
rescue Snapsbrew::ValidationError => error
  error.errors   # => {"variants.0.image_url" => ["..."]}
end
```

A 422 from an editor document operation has a `code` and no field errors, for example `editor_operation_layer_not_found`. Then `errors` is an empty Hash.

Do not read the `message` of a `NotFoundError` to know the cause. A missing record returns a message from the framework, for example `No query results for model [...]`.

### Conflicts

A `ConflictError` has one of these codes:

| `code`                             | Cause | Retry |
|------------------------------------|-------|-------|
| `idempotency_key_in_progress`      | Another request with the same `idempotency_key` is in progress. | The client retries it. A repeat with the same key is safe. |
| `idempotency_key_belongs_to_snap`  | A single snap owns the key, so `batches.create` cannot use it. | No. Send a new key. |
| `idempotency_key_belongs_to_batch` | A batch owns the key, so `snaps.create` cannot use it. | No. Send a new key. |
| `legacy_edit_rejected_for_v2`      | The template uses the v2 editor document, so `templates.update` cannot change it. | No. |
| `editor_document_conflict`         | Another write changed the editor document. | No. Make the change again on the current document. |

`error.in_progress?` is true for `idempotency_key_in_progress`.

For `editor_document_conflict`, `current_revision` and `current_document` give the stored revision and document. For each other code, they are `nil`:

```ruby
begin
  Snapsbrew.documents.apply(id, revision: 7, operations:)
rescue Snapsbrew::ConflictError => error
  error.current_revision            # => 8
  error.current_document.layers     # => [#<Snapsbrew::Record ...>]
end
```

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
