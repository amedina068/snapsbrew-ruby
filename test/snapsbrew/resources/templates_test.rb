require "test_helper"

class Snapsbrew::TemplatesTest < Snapsbrew::TestCase
  ID = "141e8454-8aa1-420a-bd0b-18a85ba949a2"

  def test_list
    stub_api(:get, "/v1/templates").to_return(json(
      data: [ { uuid: ID, title: "Template 1", layers: [ { layer: "review_title", type: "text" } ] } ],
      meta: { previous_cursor: nil, next_cursor: nil }
    ))

    page = client.templates.list

    assert_equal [ "Template 1" ], page.map(&:title)
    assert_equal "review_title", page.first.layers.first.layer
    refute page.next_page?
    assert_nil page.next_page
  end

  def test_list_walks_the_cursor
    stub_api(:get, "/v1/templates").to_return(json(data: [ { title: "One" } ], meta: { next_cursor: "abc" }))
    stub_api(:get, "/v1/templates", query: { cursor: "abc" }).to_return(json(data: [ { title: "Two" } ], meta: { next_cursor: nil }))

    page = client.templates.list

    assert page.next_page?
    assert_equal [ "Two" ], page.next_page.map(&:title)
    assert_equal %w[ One Two ], client.templates.map(&:title)
  end

  def test_find
    stub_api(:get, "/v1/templates/#{ID}").to_return(json(data: { uuid: ID, published_version: 2, has_unpublished_edits: true }))

    template = client.templates.find(ID)

    assert_equal 2, template.published_version
    assert template.has_unpublished_edits
  end

  def test_find_a_missing_template
    stub_api(:get, "/v1/templates/nope").to_return(json({ message: "Not found." }, status: 404))

    assert_raises(Snapsbrew::NotFoundError) { client.templates.find("nope") }
  end

  def test_sizes
    stub_api(:get, "/v1/templates/sizes").to_return(json(data: [ { size: "open_graph", width: 1200, height: 630 } ]))

    assert_equal [ "open_graph" ], client.templates.sizes.map(&:size)
  end

  def test_create
    stub = stub_api(:post, "/v1/templates").with(body: { title: "Launch card", size: "open_graph" })
      .to_return(json(data: { uuid: ID, size: "open_graph" }, message: "Template created successfully"))

    assert_equal ID, client.templates.create(title: "Launch card", size: "open_graph").uuid
    assert_requested stub
  end

  def test_update
    stub = stub_api(:patch, "/v1/templates/#{ID}").with(body: { title: "Updated", width: 1080, height: 1080 })
      .to_return(json(data: { uuid: ID, title: "Updated" }))

    assert_equal "Updated", client.templates.update(ID, title: "Updated", width: 1080, height: 1080).title
    assert_requested stub
  end

  def test_destroy
    stub = stub_api(:delete, "/v1/templates/#{ID}").to_return(json(message: "Template deleted successfully"))

    assert client.templates.destroy(ID)
    assert_requested stub
  end

  def test_publish_is_retried_because_it_is_idempotent
    stub = stub_api(:post, "/v1/templates/#{ID}/publish").to_return(json({}, status: 502))
      .then.to_return(json(data: { uuid: ID, published_version: 3 }))

    assert_equal 3, client.templates.publish(ID).published_version
    assert_requested stub, times: 2
  end
end
