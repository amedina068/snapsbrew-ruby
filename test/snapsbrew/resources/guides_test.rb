require "test_helper"

class Snapsbrew::GuidesTest < Snapsbrew::TestCase
  {
    design: "/v1/guides/design",
    layers: "/v1/guides/layers",
    variant_properties: "/v1/guides/variant-properties",
    editor_document: "/v1/guides/editor-document",
    platforms: "/v1/guides/platforms",
    purposes: "/v1/guides/purposes"
  }.each do |guide, path|
    define_method("test_#{guide}") do
      stub_api(:get, path).to_return(json(data: { guide: guide.to_s }))

      assert_equal guide.to_s, client.guides.public_send(guide).guide
    end
  end

  def test_platform
    stub_api(:get, "/v1/guides/platforms/instagram").to_return(json(data: { platform: "instagram", start_here: "instagram_post" }))

    assert_equal "instagram_post", client.guides.platform(:instagram).start_here
  end

  def test_purpose
    stub_api(:get, "/v1/guides/purposes/og").to_return(json(data: { purpose: "link_preview" }))

    assert_equal "link_preview", client.guides.purpose("og").purpose
  end

  def test_unknown_platform
    stub_api(:get, "/v1/guides/platforms/myspace").to_return(json({ message: "No platform guide matches `myspace`.", available: %w[ instagram x ] }, status: 404))

    error = assert_raises(Snapsbrew::NotFoundError) { client.guides.platform(:myspace) }

    assert_equal %w[ instagram x ], error.available
  end

  def test_unknown_purpose
    stub_api(:get, "/v1/guides/purposes/flyer").to_return(json({ message: "No image purpose guide matches `flyer`.", available: %w[ link_preview ] }, status: 404))

    error = assert_raises(Snapsbrew::NotFoundError) { client.guides.purpose(:flyer) }

    assert_equal %w[ link_preview ], error.available
  end
end
