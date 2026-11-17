require "test_helper"

class Snapsbrew::SignedUrlTest < Snapsbrew::TestCase
  VECTORS = JSON.parse(File.read(File.expand_path("../fixtures/signed-url-vectors.json", __dir__)))
  BASE = VECTORS["base_url"].delete_suffix(Snapsbrew::SignedUrl::PATH)

  VECTORS["cases"].each do |vector|
    name = vector["name"].tr("^a-z0-9", "_")

    define_method("test_canonical_string_#{name}") do
      assert_equal vector["canonical_string"], Snapsbrew::SignedUrl.canonical(vector["params"])
    end

    define_method("test_signature_#{name}") do
      assert_equal vector["signature"], Snapsbrew::SignedUrl.sign(vector["params"], VECTORS["key"])
    end

    define_method("test_url_#{name}") do
      variants = vector["variants_json"] && JSON.parse(vector["variants_json"])
      options = vector["params"].except("template_id", "variants").transform_keys(&:to_sym)

      url = signer.build(template: vector["params"]["template_id"], variants:, **options)

      assert_equal vector["url"], url
    end
  end

  def test_canonical_string_ignores_the_signature_and_sorts_by_byte_order
    assert_equal "B=2&a=1&b=3", Snapsbrew::SignedUrl.canonical("b" => "3", "signature" => "x", "a" => "1", "B" => "2")
  end

  def test_a_transparent_jpeg_is_an_error
    [ true, "1", "true" ].each do |transparent|
      assert_raises(ArgumentError) { signer.build(template: "t1", format: "jpeg", transparent:) }
    end
  end

  def test_a_transparent_png_and_an_opaque_jpeg_are_valid
    assert_includes signer.build(template: "t1", format: "png", transparent: true), "transparent=true"
    assert_includes signer.build(template: "t1", format: "jpeg", transparent: false), "transparent=false"
  end

  def test_keyword_layers_build_the_same_url_as_the_array_form
    array = signer.build(template: "t1", variants: [ { layer: "title", text: "Dark Avengers" } ])

    assert_equal array, signer.build(template: "t1", title: "Dark Avengers")
    assert_equal array, signer.build(template: "t1", variants: { title: "Dark Avengers" })
  end

  def test_variants_are_standard_base64_of_the_json_array
    url = signer.build(template: "t1", headline: "¿Sí? 🏹", cover: "https://example.com/a.jpg?x=1&y=2", badge: false)
    encoded = URI.decode_www_form(URI(url).query).to_h["variants"]

    assert_equal [
      { "layer" => "headline", "text" => "¿Sí? 🏹" },
      { "layer" => "cover", "image_url" => "https://example.com/a.jpg?x=1&y=2" },
      { "layer" => "badge", "hidden" => true }
    ], JSON.parse(encoded.unpack1("m0"))
  end

  def test_transparent_is_part_of_the_signature
    url = signer.build(template: "t1", format: "png", transparent: true)
    params = URI.decode_www_form(URI(url).query).to_h

    assert_equal "true", params["transparent"]
    assert_equal Snapsbrew::SignedUrl.sign(params, VECTORS["key"]), params["signature"]
  end

  def test_trailing_slash_and_api_suffix_on_the_instance_url
    assert client(url: "https://snaps.test/api/").signed_url(template: "t1").start_with?("https://snaps.test/signed-url/image.jpg?")
  end

  def test_missing_signing_key
    error = assert_raises(Snapsbrew::ConfigurationError) do
      Snapsbrew::Client.new(url: URL, token: TOKEN).signed_url(template: "t1")
    end

    assert_match "signing_key", error.message
  end

  def test_missing_url
    assert_raises(Snapsbrew::ConfigurationError) do
      Snapsbrew::Client.new(signing_key: "key").signed_url(template: "t1")
    end
  end

  def test_inspect_hides_the_key
    refute_includes signer.inspect, VECTORS["key"]
  end

  private
    def signer
      Snapsbrew::SignedUrl.new(url: BASE, key: VECTORS["key"])
    end
end
