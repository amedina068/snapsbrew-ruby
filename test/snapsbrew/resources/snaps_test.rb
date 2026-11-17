require "test_helper"

class Snapsbrew::SnapsTest < Snapsbrew::TestCase
  ID = "141e8454-8aa1-420a-bd0b-18a85ba949a2"

  def test_create_maps_a_hash_of_variants_to_the_api_array
    stub = stub_api(:post, "/v1/snaps").with(body: {
      template_id: ID,
      variants: [ { layer: "title", text: "Hello" }, { layer: "cover", image_url: "https://example.com/a.jpg" } ]
    }).to_return(json({ id: "9f1c2d3e", status: "completed", media_url: "https://snaps.test/storage/snaps/9f1c2d3e.png" }, status: 201))

    snap = client.snaps.create(template: ID, variants: { title: "Hello", cover: "https://example.com/a.jpg" })

    assert_equal "https://snaps.test/storage/snaps/9f1c2d3e.png", snap.media_url
    assert_requested stub
  end

  def test_create_accepts_the_array_form
    variants = [ { layer: "title", text: "Hello" } ]
    stub = stub_api(:post, "/v1/snaps").with(body: { template_id: ID, variants: }).to_return(json({ id: "s1" }, status: 201))

    client.snaps.create(template: ID, variants:)

    assert_requested stub
  end

  def test_create_sends_every_option
    stub = stub_api(:post, "/v1/snaps").with(body: {
      template_id: ID, type: "image", format: "webp", transparent: true, async: true,
      webhook_url: "https://example.com/hooks/snap", idempotency_key: "order-1"
    }).to_return(json({ id: "s1", status: "pending", is_async: true }, status: 202))

    snap = client.snaps.create(template: ID, type: "image", format: "webp", transparent: true, async: true,
                               webhook_url: "https://example.com/hooks/snap", idempotency_key: "order-1")

    assert_equal "pending", snap.status
    assert_requested stub
  end

  def test_create_from_a_collection_returns_an_array
    stub_api(:post, "/v1/snaps").with(body: { collection_id: "c1" })
      .to_return(json([ { id: "s1" }, { id: "s2" } ], status: 201))

    assert_equal %w[ s1 s2 ], client.snaps.create(collection: "c1").map(&:id)
  end

  def test_preview_sends_variants_in_the_nested_query_form
    stub = stub_request(:get, "#{URL}/api/v1/snaps/preview?template_id=#{ID}" \
      "&variants%5B0%5D%5Blayer%5D=title&variants%5B0%5D%5Btext%5D=Hello" \
      "&variants%5B1%5D%5Blayer%5D=badge&variants%5B1%5D%5Bhidden%5D=1")
      .to_return(status: 200, body: "<!DOCTYPE html>…watermarked preview…</html>", headers: { "Content-Type" => "text/html; charset=UTF-8" })

    html = client.snaps.preview(template: ID, variants: { title: "Hello", badge: false })

    assert_includes html, "watermarked preview"
    assert_requested stub
  end

  def test_preview_rate_limit
    stub_api(:get, "/v1/snaps/preview", query: { template_id: ID })
      .to_return(json({ message: "Too Many Attempts." }, status: 429, headers: { "Retry-After" => "3600" }))

    assert_raises(Snapsbrew::RateLimitError) { client.snaps.preview(template: ID) }
  end
end
