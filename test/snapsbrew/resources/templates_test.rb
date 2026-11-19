require "test_helper"

class Snapsbrew::TemplatesTest < Snapsbrew::TestCase
  ID = "141e8454-8aa1-420a-bd0b-18a85ba949a2"

  def test_list
    stub_api(:get, "/v1/templates").to_return(json(
      data: [ { uuid: ID, title: "Template 1", width: 1200, height: 630, created_at: "2026-05-01T12:00:00.000000Z",
                layers: [ { layer: "review_title", available_modifications: { text: "The worst Time-Travel movie ever made" } } ] } ],
      meta: { previous_cursor: nil, next_cursor: nil }
    ))

    page = client.templates.list

    assert_equal [ "Template 1" ], page.map(&:title)
    assert_equal "review_title", page.first.layers.first.layer
    assert_equal "The worst Time-Travel movie ever made", page.first.layers.first.available_modifications.text
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
    stub_api(:get, "/v1/templates/#{ID}").to_return(json(data: {
      uuid: ID, title: "Movie review", size: "open_graph", width: 1200, height: 630,
      layers: [
        { layer: "review_title", available_modifications: { text: "The worst Time-Travel movie ever made" } },
        { layer: "frame", available_modifications: [] }
      ],
      published_version: 2, has_unpublished_edits: true, created_at: "2026-05-01T12:00:00.000000Z"
    }))

    template = client.templates.find(ID)

    assert_equal 2, template.published_version
    assert template.has_unpublished_edits
    assert_equal %w[ review_title frame ], template.layers.map(&:layer)
  end

  def test_a_layer_with_no_override_has_an_empty_map
    stub_api(:get, "/v1/templates/#{ID}").to_return(json(data: { uuid: ID, layers: [ { layer: "frame", available_modifications: [] } ] }))
    stub_api(:get, "/v1/templates").to_return(json(data: [ { uuid: ID, layers: [ { layer: "frame", available_modifications: [] } ] } ], meta: {}))

    assert_equal({}, client.templates.find(ID).layers.first.available_modifications.to_h)
    assert_equal({}, client.templates.list.first.layers.first.available_modifications.to_h)
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
      .to_return(json({ data: { uuid: ID, title: "Launch card", size: "open_graph", width: 1200, height: 630, created_at: "2026-05-01T12:00:00.000000Z" },
                        message: "Template created successfully" }, status: 201))

    assert_equal ID, client.templates.create(title: "Launch card", size: "open_graph").uuid
    assert_requested stub
  end

  def test_create_with_layer_objects
    layers = [ { key: "title", type: "text", properties: [ { name: "textContent", value: "Hello" } ] } ]
    stub = stub_api(:post, "/v1/templates").with(body: { title: "Launch card", layers: })
      .to_return(json({ data: { uuid: ID }, message: "Template created successfully" }, status: 201))

    client.templates.create(title: "Launch card", layers:)

    assert_requested stub
  end

  def test_create_with_groups
    groups = [ { id: "header", name: "Header", visible: true, collapsed: false, order: 0 } ]
    stub = stub_api(:post, "/v1/templates").with(body: { title: "Launch card", size: "open_graph", groups: })
      .to_return(json({ data: { uuid: ID }, message: "Template created successfully" }, status: 201))

    client.templates.create(title: "Launch card", size: "open_graph", groups:)

    assert_requested stub
  end

  def test_update
    stub = stub_api(:patch, "/v1/templates/#{ID}").with(body: { title: "Updated", width: 1080, height: 1080 })
      .to_return(json(data: { uuid: ID, title: "Updated" }))

    assert_equal "Updated", client.templates.update(ID, title: "Updated", width: 1080, height: 1080).title
    assert_requested stub
  end

  def test_update_with_groups
    stub = stub_api(:patch, "/v1/templates/#{ID}").with(body: { title: "Updated", groups: [ { id: "header" } ] })
      .to_return(json(data: { uuid: ID, title: "Updated" }))

    client.templates.update(ID, title: "Updated", groups: [ { id: "header" } ])

    assert_requested stub
  end

  def test_update_with_a_bad_field_is_a_validation_error
    stub_api(:patch, "/v1/templates/#{ID}").to_return(json({
      message: "The groups.0.id field is required.", errors: { "groups.0.id": [ "The groups.0.id field is required." ] }
    }, status: 422))

    error = assert_raises(Snapsbrew::ValidationError) { client.templates.update(ID, title: "Updated", groups: [ { name: "Header" } ]) }

    assert_equal [ "The groups.0.id field is required." ], error.errors["groups.0.id"]
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
