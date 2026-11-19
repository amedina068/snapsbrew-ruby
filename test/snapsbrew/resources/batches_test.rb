require "test_helper"

class Snapsbrew::BatchesTest < Snapsbrew::TestCase
  ID = "7c1f2a9e-0b44-4a1e-9f2b-5d3c8e1a7b60"

  def test_create
    stub = stub_api(:post, "/v1/snaps/batches").with(body: {
      template_id: "t1",
      items: [
        { identifier: "row-1", variants: [ { layer: "title", text: "Hello" } ] },
        { variants: [ { layer: "title", text: "World" } ] }
      ],
      title: "October launch"
    }).to_return(json({
      uuid: ID, title: "October launch", status: "pending", total_rows: 2, processed_rows: 0,
      completed: 0, pending: 2, failed: 0, canceled: 0, status_url: "#{URL}/api/v1/snaps/batches/#{ID}"
    }, status: 202))

    batch = client.batches.create(template: "t1", title: "October launch", items: [
      { identifier: "row-1", variants: { title: "Hello" } },
      { variants: [ { layer: "title", text: "World" } ] }
    ])

    assert_equal ID, batch.uuid
    assert_equal 2, batch.pending
    assert_requested stub
  end

  def test_create_with_too_many_items
    stub_api(:post, "/v1/snaps/batches").to_return(json({
      message: "A batch accepts at most 100 items. Split the request into smaller batches.",
      errors: { items: [ "A batch accepts at most 100 items. Split the request into smaller batches." ] }
    }, status: 422))

    error = assert_raises(Snapsbrew::ValidationError) { client.batches.create(template: "t1", items: [ {} ] * 101) }

    assert error.errors.key?("items")
  end

  def test_create_conflict
    stub_api(:post, "/v1/snaps/batches").to_return(json({
      message: "This idempotency_key already belongs to a single snap. Use a new key for a batch.", code: "idempotency_key_belongs_to_snap"
    }, status: 409))

    error = assert_raises(Snapsbrew::ConflictError) { client.batches.create(template: "t1", items: [ {} ], idempotency_key: "k") }

    assert_equal "idempotency_key_belongs_to_snap", error.code
  end

  def test_create_server_error_has_the_internal_error_code
    message = "The server could not create the batch. Try again later. If the error continues, " \
      "contact support and give the X-Request-Uuid header of this response."
    stub = stub_api(:post, "/v1/snaps/batches")
      .to_return(json({ message:, code: "internal_error" }, status: 500, headers: { "X-Request-Uuid" => "req-batch" }))

    error = assert_raises(Snapsbrew::ServerError) { client.batches.create(template: "t1", items: [ {} ]) }

    assert_equal message, error.message
    assert_equal "internal_error", error.code
    assert_equal "req-batch", error.request_id
    assert_requested stub, times: 1
  end

  def test_find
    stub_api(:get, "/v1/snaps/batches/#{ID}").to_return(json({
      uuid: ID, title: "October launch", status: "completed", total_rows: 2, processed_rows: 2,
      completed: 1, pending: 0, failed: 1, canceled: 0, status_url: "#{URL}/api/v1/snaps/batches/#{ID}",
      items: [
        { id: "9f1c2d3e", identifier: "row-1", status: "completed", media_url: "https://snaps.test/a.png", last_error: nil },
        { id: "4b8a7c6d", identifier: "item_2", status: "failed", media_url: nil, last_error: "render_failed" }
      ]
    }))

    batch = client.batches.find(ID)

    assert_equal "completed", batch.status
    assert_equal [ "https://snaps.test/a.png" ], batch.items.filter_map(&:media_url)
    assert_equal [ nil, "render_failed" ], batch.items.map(&:last_error)
  end

  def test_cancel_is_retried_because_it_is_idempotent
    stub = stub_api(:post, "/v1/snaps/batches/#{ID}/cancel").to_return(json({}, status: 500))
      .then.to_return(json({ uuid: ID, status: "canceled", canceled: 2 }))

    assert_equal "canceled", client.batches.cancel(ID).status
    assert_requested stub, times: 2
  end
end
