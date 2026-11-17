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
    }).to_return(json({ uuid: ID, status: "processing", total_rows: 2 }, status: 202))

    batch = client.batches.create(template: "t1", title: "October launch", items: [
      { identifier: "row-1", variants: { title: "Hello" } },
      { variants: [ { layer: "title", text: "World" } ] }
    ])

    assert_equal ID, batch.uuid
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
    stub_api(:post, "/v1/snaps/batches").to_return(json({ message: "This idempotency_key already belongs to a single snap." }, status: 409))

    assert_raises(Snapsbrew::ConflictError) { client.batches.create(template: "t1", items: [ {} ], idempotency_key: "k") }
  end

  def test_find
    stub_api(:get, "/v1/snaps/batches/#{ID}").to_return(json({
      uuid: ID, status: "completed", completed: 1, failed: 1,
      items: [ { id: "9f1c2d3e", status: "completed", media_url: "https://snaps.test/a.png" }, { id: "4b8a7c6d", status: "failed", media_url: nil } ]
    }))

    batch = client.batches.find(ID)

    assert_equal "completed", batch.status
    assert_equal [ "https://snaps.test/a.png" ], batch.items.filter_map(&:media_url)
  end

  def test_cancel_is_retried_because_it_is_idempotent
    stub = stub_api(:post, "/v1/snaps/batches/#{ID}/cancel").to_return(json({}, status: 500))
      .then.to_return(json({ uuid: ID, status: "canceled", canceled: 2 }))

    assert_equal "canceled", client.batches.cancel(ID).status
    assert_requested stub, times: 2
  end
end
