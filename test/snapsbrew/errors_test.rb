require "test_helper"

class Snapsbrew::ErrorsTest < Snapsbrew::TestCase
  {
    400 => Snapsbrew::ApiError,
    401 => Snapsbrew::AuthenticationError,
    403 => Snapsbrew::AuthorizationError,
    404 => Snapsbrew::NotFoundError,
    409 => Snapsbrew::ConflictError,
    422 => Snapsbrew::ValidationError,
    429 => Snapsbrew::RateLimitError,
    500 => Snapsbrew::ServerError,
    503 => Snapsbrew::ServerError
  }.each do |status, error_class|
    define_method("test_status_#{status}_raises_#{error_class.name.split("::").last}") do
      stub_api(:post, "/v1/snaps").to_return(json({ message: "Nope." }, status:, headers: { "X-Request-Uuid" => "req-1" }))

      error = assert_raises(error_class) { client(max_retries: 0).snaps.create(template: "t1") }

      assert_equal status, error.status
      assert_equal "Nope.", error.message
      assert_equal "req-1", error.request_id
      assert_kind_of Snapsbrew::Error, error
    end
  end

  {
    account: ->(client) { client.account },
    guides_design: ->(client) { client.guides.design },
    guides_platform: ->(client) { client.guides.platform(:instagram) },
    guides_purpose: ->(client) { client.guides.purpose(:og) },
    templates_list: ->(client) { client.templates.list },
    templates_find: ->(client) { client.templates.find("t1") },
    templates_sizes: ->(client) { client.templates.sizes },
    templates_create: ->(client) { client.templates.create(title: "Card", size: "open_graph") },
    templates_update: ->(client) { client.templates.update("t1", title: "Card") },
    templates_destroy: ->(client) { client.templates.destroy("t1") },
    templates_publish: ->(client) { client.templates.publish("t1") },
    documents_find: ->(client) { client.documents.find("t1") },
    documents_replace: ->(client) { client.documents.replace("t1", revision: 1, document: { layers: [] }) },
    documents_apply: ->(client) { client.documents.apply("t1", revision: 1, operations: []) },
    documents_preflight: ->(client) { client.documents.preflight("t1") },
    snaps_create: ->(client) { client.snaps.create(template: "t1") },
    snaps_preview: ->(client) { client.snaps.preview(template: "t1") },
    batches_create: ->(client) { client.batches.create(template: "t1", items: [ { variants: { title: "Hi" } } ]) },
    batches_find: ->(client) { client.batches.find("b1") },
    batches_cancel: ->(client) { client.batches.cancel("b1") },
    screenshots_create: ->(client) { client.screenshots.create(url: "https://example.com") },
    screenshots_list: ->(client) { client.screenshots.list },
    screenshots_find: ->(client) { client.screenshots.find("s1") },
    media_upload: ->(client) { client.media.upload(StringIO.new("x")) },
    media_list: ->(client) { client.media.list },
    tags_list: ->(client) { client.tags.list },
    tags_create: ->(client) { client.tags.create(name: "Launch") },
    templates_set_tags: ->(client) { client.templates.set_tags("t1", [ 1 ]) },
    templates_preview: ->(client) { client.templates.preview("t1") }
  }.each do |operation, call|
    define_method("test_a_token_without_the_ability_is_an_authorization_error_on_#{operation}") do
      stub = stub_request(:any, /\A#{URL}/).to_return(json({ message: "Invalid ability provided." }, status: 403))

      error = assert_raises(Snapsbrew::AuthorizationError) { call.(client) }

      assert_equal "Invalid ability provided.", error.message
      assert_requested stub, times: 1
    end
  end

  def test_a_refused_snap_is_an_authorization_error
    stub_api(:post, "/v1/snaps").to_return(json({ message: "This action is unauthorized." }, status: 403))

    error = assert_raises(Snapsbrew::AuthorizationError) { client.snaps.create(template: "t1") }

    assert_equal "This action is unauthorized.", error.message
  end

  %w[ idempotency_key_in_progress idempotency_key_belongs_to_snap idempotency_key_belongs_to_batch ].each do |code|
    define_method("test_conflict_error_carries_the_code_#{code}") do
      stub_api(:post, "/v1/snaps").to_return(json({ message: "The idempotency_key cannot be used.", code: }, status: 409))

      error = assert_raises(Snapsbrew::ConflictError) { client(max_retries: 0).snaps.create(template: "t1", idempotency_key: "k") }

      assert_equal code, error.code
      assert_equal code == "idempotency_key_in_progress", error.in_progress?
    end
  end

  def test_a_body_with_a_code_and_no_message
    stub_api(:patch, "/v1/templates/t1").to_return(json({ code: "legacy_edit_rejected_for_v2" }, status: 409))

    error = assert_raises(Snapsbrew::ConflictError) { client.templates.update("t1", title: "New") }

    assert_equal "legacy_edit_rejected_for_v2", error.code
    assert_equal "Snapsbrew returned HTTP 409: legacy_edit_rejected_for_v2", error.message
  end

  def test_server_error_with_the_internal_error_code
    message = "The server could not create the snap. Try again later. If the error continues, " \
      "contact support and give the X-Request-Uuid header of this response."
    stub_api(:post, "/v1/snaps").to_return(json({ message:, code: "internal_error" }, status: 500, headers: { "X-Request-Uuid" => "req-9" }))

    error = assert_raises(Snapsbrew::ServerError) { client.snaps.create(template: "t1") }

    assert_equal message, error.message
    assert_equal "internal_error", error.code
    assert_equal "req-9", error.request_id
  end

  def test_an_error_without_a_code
    stub_api(:get, "/v1/templates/nope").to_return(json({ message: "Not found." }, status: 404))

    assert_nil assert_raises(Snapsbrew::NotFoundError) { client.templates.find("nope") }.code
  end

  def test_a_missing_record_is_a_not_found_error_whatever_the_message
    stub_api(:get, "/v1/snaps/batches/nope").to_return(json({ message: "No query results for model [App\\Models\\SnapImport]." }, status: 404))

    error = assert_raises(Snapsbrew::NotFoundError) { client.batches.find("nope") }

    assert_equal "No query results for model [App\\Models\\SnapImport].", error.message
    assert_equal [], error.available
  end

  def test_an_editor_document_conflict_carries_the_current_revision_and_document
    stub_api(:put, "/v1/templates/t1/document").to_return(json({
      code: "editor_document_conflict", current_revision: 8, current_document: { layers: [ { id: "title" } ], groups: [] }
    }, status: 409))

    error = assert_raises(Snapsbrew::ConflictError) { client.request(:put, "/v1/templates/t1/document", json: { revision: 7 }) }

    assert_equal "editor_document_conflict", error.code
    assert_equal 8, error.current_revision
    assert_equal "title", error.current_document.layers.first.id
    refute error.in_progress?
  end

  def test_a_conflict_without_a_document
    stub_api(:patch, "/v1/templates/t1").to_return(json({ code: "legacy_edit_rejected_for_v2" }, status: 409))

    error = assert_raises(Snapsbrew::ConflictError) { client.templates.update("t1", title: "New") }

    assert_nil error.current_revision
    assert_nil error.current_document
  end

  def test_an_editor_operation_error_is_a_validation_error_with_a_code
    stub_api(:patch, "/v1/templates/t1/document").to_return(json({ code: "editor_operation_layer_not_found" }, status: 422))

    error = assert_raises(Snapsbrew::ValidationError) { client.request(:patch, "/v1/templates/t1/document", json: { revision: 7 }) }

    assert_equal "editor_operation_layer_not_found", error.code
    assert_equal({}, error.errors)
    assert_equal "Snapsbrew returned HTTP 422: editor_operation_layer_not_found", error.message
  end

  def test_a_bad_cursor_is_a_validation_error
    stub_api(:get, "/v1/templates", query: { cursor: "bad" }).to_return(json({
      message: "The cursor is not valid.", errors: { cursor: [ "The cursor is not valid." ] }
    }, status: 422))

    error = assert_raises(Snapsbrew::ValidationError) { client.templates.list(cursor: "bad") }

    assert_equal [ "The cursor is not valid." ], error.errors["cursor"]
  end

  def test_validation_error_carries_the_field_errors
    stub_api(:post, "/v1/snaps").to_return(json({
      message: "The template id field is required when collection id is not present.",
      errors: { template_id: [ "The template id field is required when collection id is not present." ] }
    }, status: 422))

    error = assert_raises(Snapsbrew::ValidationError) { client.snaps.create }

    assert_equal [ "The template id field is required when collection id is not present." ], error.errors["template_id"]
  end

  def test_validation_error_without_field_errors
    stub_api(:post, "/v1/media").to_return(json({ message: "The file must be an image." }, status: 422))

    error = assert_raises(Snapsbrew::ValidationError) { client.media.upload(StringIO.new("x")) }

    assert_equal({}, error.errors)
  end

  def test_rate_limit_error_carries_retry_after_in_seconds
    stub_api(:get, "/v1/auth").to_return(json({ message: "Too Many Attempts." }, status: 429, headers: { "Retry-After" => "42" }))

    error = assert_raises(Snapsbrew::RateLimitError) { client(max_retries: 0).account }

    assert_equal 42, error.retry_after
  end

  def test_rate_limit_error_carries_the_limit
    stub_api(:get, "/v1/snaps/preview", query: { template_id: "t1" }).to_return(json({ message: "Too Many Attempts." }, status: 429,
      headers: { "Retry-After" => "42", "X-RateLimit-Limit" => "10", "X-RateLimit-Remaining" => "0" }))

    error = assert_raises(Snapsbrew::RateLimitError) { client(max_retries: 0).snaps.preview(template: "t1") }

    assert_equal 10, error.limit
  end

  def test_retry_after_as_an_http_date
    stub_api(:get, "/v1/auth").to_return(json({}, status: 429, headers: { "Retry-After" => (Time.now + 30).httpdate }))

    error = assert_raises(Snapsbrew::RateLimitError) { client(max_retries: 0).account }

    assert_in_delta 30, error.retry_after, 2
  end

  def test_a_body_that_is_not_json
    stub_api(:get, "/v1/auth").to_return(status: 502, body: "<html>Bad Gateway</html>")

    error = assert_raises(Snapsbrew::ServerError) { client(max_retries: 0).account }

    assert_equal "Snapsbrew returned HTTP 502", error.message
    assert_equal "<html>Bad Gateway</html>", error.body
  end

  def test_connection_error
    stub_api(:get, "/v1/auth").to_raise(Errno::ECONNREFUSED)

    error = assert_raises(Snapsbrew::ConnectionError) { client(max_retries: 0).account }

    assert_kind_of Errno::ECONNREFUSED, error.cause
  end

  def test_timeout_is_a_connection_error
    stub_api(:get, "/v1/auth").to_timeout

    assert_raises(Snapsbrew::ConnectionError) { client(max_retries: 0).account }
  end

  def test_tls_error_is_a_connection_error
    stub_api(:get, "/v1/auth").to_raise(OpenSSL::SSL::SSLError)

    assert_raises(Snapsbrew::ConnectionError) { client.account }
  end
end
