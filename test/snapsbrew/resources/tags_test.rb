require "test_helper"

class Snapsbrew::TagsTest < Snapsbrew::TestCase
  def test_list
    stub_api(:get, "/v1/tags", query: { search: "lau" }).to_return(json(data: [ { id: 1, name: "Launch" } ]))

    assert_equal [ "Launch" ], client.tags.list(search: "lau").map(&:name)
  end

  def test_create
    stub_api(:post, "/v1/tags").with(body: { name: "Launch" }).to_return(json({ data: { id: 1, slug: "launch" } }, status: 201))

    assert_equal "launch", client.tags.create(name: "Launch").slug
  end

  def test_sync
    stub = stub_api(:post, "/v1/templates/t1/tags").with(body: { tag_ids: [ 1 ] })
      .to_return(json(message: "Tags updated successfully.", tags: [ { id: 1, name: "Launch" } ]))

    assert_equal [ 1 ], client.tags.sync(template: "t1", tag_ids: [ 1 ]).map(&:id)
    assert_requested stub
  end
end
