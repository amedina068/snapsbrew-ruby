require "test_helper"

class Snapsbrew::ScreenshotsTest < Snapsbrew::TestCase
  def test_create
    stub = stub_api(:post, "/v1/screenshots").with(body: { url: "https://example.com", width: 1280 })
      .to_return(json(data: { id: "a1b2c3", image_url: "https://snaps.test/a1b2c3.png" }))

    assert_equal "https://snaps.test/a1b2c3.png", client.screenshots.create(url: "https://example.com", width: 1280).image_url
    assert_requested stub
  end

  def test_list
    stub_api(:get, "/v1/screenshots").to_return(json(data: [ { uuid: "a1b2c3" } ], meta: { next_cursor: nil }))

    assert_equal [ "a1b2c3" ], client.screenshots.list.map(&:uuid)
    assert_equal [ "a1b2c3" ], client.screenshots.map(&:uuid)
  end

  def test_find
    stub_api(:get, "/v1/screenshots/a1b2c3").to_return(json(data: { id: "a1b2c3", width: 1330 }))

    assert_equal 1330, client.screenshots.find("a1b2c3").width
  end
end
