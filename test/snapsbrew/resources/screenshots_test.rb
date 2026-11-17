require "test_helper"

class Snapsbrew::ScreenshotsTest < Snapsbrew::TestCase
  UUID = "a1b2c3d4-0000-4000-8000-000000000001"
  IMAGE_URL = "https://snaps.test/storage/screenshots/a1b2c3d4.png"
  def test_create
    stub = stub_api(:post, "/v1/screenshots").with(body: { url: "https://example.com", width: 1280 })
      .to_return(json(data: screenshot(id: UUID, width: 1280)))

    assert_equal IMAGE_URL, client.screenshots.create(url: "https://example.com", width: 1280).image_url
    assert_requested stub
  end

  def test_list_reads_the_image_url_of_each_item
    stub_api(:get, "/v1/screenshots").to_return(json(data: [ screenshot(uuid: UUID) ], meta: { previous_cursor: nil, next_cursor: nil }))

    assert_equal [ UUID ], client.screenshots.list.map(&:uuid)
    assert_equal [ IMAGE_URL ], client.screenshots.map(&:image_url)
  end

  def test_find
    stub_api(:get, "/v1/screenshots/#{UUID}").to_return(json(data: screenshot(id: UUID)))

    screenshot = client.screenshots.find(UUID)

    assert_equal 1330, screenshot.width
    assert_equal IMAGE_URL, screenshot.image_url
  end

  def test_image_url_is_nil_when_the_screenshot_has_no_image
    stub_api(:post, "/v1/screenshots").to_return(json(data: screenshot(id: UUID, image_url: nil)))
    stub_api(:get, "/v1/screenshots/#{UUID}").to_return(json(data: screenshot(id: UUID, image_url: nil)))
    stub_api(:get, "/v1/screenshots")
      .to_return(json(data: [ screenshot(uuid: UUID, image_url: nil) ], meta: { previous_cursor: nil, next_cursor: nil }))

    assert_nil client.screenshots.create(url: "https://example.com").image_url
    assert_nil client.screenshots.find(UUID).image_url
    assert_equal [ nil ], client.screenshots.map(&:image_url)
  end

  private
    # The read and the create name the id `id`. A list item names it `uuid`.
    def screenshot(width: 1330, image_url: IMAGE_URL, **id)
      { **id, url: "https://example.com", image_url:, width:, height: 780, created_at: "2026-05-01T12:00:00.000000Z" }
    end
end
