require "test_helper"

class Snapsbrew::DocumentsTest < Snapsbrew::TestCase
  ID = "141e8454-8aa1-420a-bd0b-18a85ba949a2"
  PATH = "/v1/templates/#{ID}/document"
  DOCUMENT = { version: 2, layers: [ { key: "headline", type: "text", properties: [ { name: "fontWeight", value: 700 } ] } ], groups: [] }.freeze

  def test_find
    stub_api(:get, PATH).to_return(json(document: DOCUMENT, revision: 4))

    document = client.documents.find(ID)

    assert_equal 4, document.revision
    assert_equal "headline", document.document.layers.first.key
  end

  def test_find_a_template_with_no_draft
    stub_api(:get, PATH).to_return(json(document: nil, revision: 0))

    document = client.documents.find(ID)

    assert_equal 0, document.revision
    assert_nil document.document
  end

  def test_replace
    stub = stub_api(:put, PATH).with(body: { revision: 4, document: DOCUMENT })
      .to_return(json(document: DOCUMENT, revision: 5))

    assert_equal 5, client.documents.replace(ID, revision: 4, document: DOCUMENT).revision
    assert_requested stub
  end

  def test_replace_is_not_retried_after_a_server_error
    stub = stub_api(:put, PATH).to_return(json({ message: "Server Error" }, status: 502))

    assert_raises(Snapsbrew::ServerError) { client.documents.replace(ID, revision: 4, document: DOCUMENT) }
    assert_requested stub, times: 1
  end

  def test_replace_is_not_retried_after_a_read_timeout
    stub = stub_api(:put, "/v1/templates/#{ID}/document").to_raise(Net::ReadTimeout)

    assert_raises(Snapsbrew::ConnectionError) { client.documents.replace(ID, revision: 4, document: { layers: [] }) }
    assert_requested stub, times: 1
  end

  def test_replace_conflict_carries_the_current_document
    stub = stub_api(:put, PATH).to_return(json({ code: "editor_document_conflict", current_revision: 6, current_document: DOCUMENT }, status: 409))

    error = assert_raises(Snapsbrew::ConflictError) { client.documents.replace(ID, revision: 4, document: DOCUMENT) }

    assert_equal "editor_document_conflict", error.code
    assert_equal 6, error.current_revision
    assert_equal "headline", error.current_document.layers.first.key
    assert_requested stub, times: 1
  end

  def test_replace_a_missing_template
    stub_api(:put, PATH).to_return(json({ message: "No query results for model [App\\Models\\Template]." }, status: 404))

    assert_raises(Snapsbrew::NotFoundError) { client.documents.replace(ID, revision: 4, document: DOCUMENT) }
  end

  def test_apply
    operations = [
      { operation: "set_layer_property", layer_key: "headline", property: "fontWeight", value: 700 },
      { operation: "set_layer_type", layer_key: "logo", type: "image" }
    ]
    stub = stub_api(:patch, PATH).with(body: { revision: 4, operations: })
      .to_return(json(document: DOCUMENT, revision: 5))

    assert_equal 5, client.documents.apply(ID, revision: 4, operations:).revision
    assert_requested stub
  end

  def test_apply_conflict
    stub_api(:patch, PATH).to_return(json({ code: "editor_document_conflict", current_revision: 6, current_document: DOCUMENT }, status: 409))

    error = assert_raises(Snapsbrew::ConflictError) { client.documents.apply(ID, revision: 4, operations: []) }

    assert_equal 6, error.current_revision
  end

  def test_apply_operation_error_has_a_code_and_no_field_errors
    stub_api(:patch, PATH).to_return(json({ code: "editor_operation_layer_not_found" }, status: 422))

    error = assert_raises(Snapsbrew::ValidationError) do
      client.documents.apply(ID, revision: 4, operations: [ { operation: "set_layer_type", layer_key: "nope", type: "text" } ])
    end

    assert_equal "editor_operation_layer_not_found", error.code
    assert_equal({}, error.errors)
  end

  def test_apply_with_a_malformed_body_has_field_errors
    stub_api(:patch, PATH).to_return(json({
      message: "The operations field is required.", errors: { operations: [ "The operations field is required." ] }
    }, status: 422))

    error = assert_raises(Snapsbrew::ValidationError) { client.documents.apply(ID, revision: 4, operations: []) }

    assert_nil error.code
    assert_equal [ "The operations field is required." ], error.errors["operations"]
  end

  def test_preflight
    stub_api(:get, "#{PATH}/preflight").to_return(json(
      issues: [ { code: "image_asset_missing", path: "/layers/0/source", message: "Image layers require a pinned asset id." } ],
      revision: 4
    ))

    preflight = client.documents.preflight(ID)

    assert_equal 4, preflight.revision
    assert_equal [ "image_asset_missing" ], preflight.issues.map(&:code)
  end

  def test_a_read_is_retried_because_it_is_idempotent
    stub = stub_api(:get, PATH).to_return(json({}, status: 503)).then.to_return(json(document: DOCUMENT, revision: 4))

    assert_equal 4, client.documents.find(ID).revision
    assert_requested stub, times: 2
  end

  def test_the_uuid_is_escaped
    stub = stub_api(:get, "/v1/templates/a%2Fb/document").to_return(json(document: nil, revision: 0))

    client.documents.find("a/b")

    assert_requested stub
  end
end
