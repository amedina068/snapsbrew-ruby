require "rails_helper"

class Snapsbrew::RailtieTest < ActiveSupport::TestCase
  test "reads the settings from the credentials" do
    assert_equal "https://snaps.test", Snapsbrew.config.url
    assert_equal "credentials-token", Snapsbrew.config.token
    assert_equal "credentials-key", Snapsbrew.config.signing_key
  end

  test "an initializer runs after the credentials and wins" do
    assert_equal 5, Snapsbrew.config.timeout
    assert_equal 5, Snapsbrew.client.timeout
  end

  test "the default client uses the credentials" do
    assert_equal "https://snaps.test", Snapsbrew.client.url
  end
end

class Snapsbrew::HelperTest < ActionView::TestCase
  test "snapsbrew_image_tag wraps image_tag with a signed URL" do
    html = snapsbrew_image_tag(template: "t1", alt: "Dark Avengers", title: "Dark Avengers", html: { class: "cover", loading: "lazy" })
    img = Nokogiri::HTML5.fragment(html).at("img")

    assert_equal Snapsbrew.signed_url(template: "t1", title: "Dark Avengers"), img["src"]
    assert_equal "Dark Avengers", img["alt"]
    assert_equal "cover", img["class"]
    assert_equal "lazy", img["loading"]
    assert_valid_signature img["src"]
  end

  test "snapsbrew_image_tag passes format to the signed URL" do
    src = Nokogiri::HTML5.fragment(snapsbrew_image_tag(template: "t1", alt: "", format: "webp")).at("img")["src"]

    assert_equal "webp", query(src)["format"]
    assert_valid_signature src
  end

  test "snapsbrew_og_image_tag renders the og:image meta tag" do
    meta = Nokogiri::HTML5.fragment(snapsbrew_og_image_tag(template: "t1", title: "Dark Avengers")).at("meta")

    assert_equal "og:image", meta["property"]
    assert_equal Snapsbrew.signed_url(template: "t1", title: "Dark Avengers"), meta["content"]
  end

  private
    def query(url) = URI.decode_www_form(URI(url).query).to_h

    def assert_valid_signature(url)
      params = query(url)
      assert_equal Snapsbrew::SignedUrl.sign(params, "credentials-key"), params["signature"]
    end
end

class Snapsbrew::ViewTest < ActionDispatch::IntegrationTest
  test "a view renders both helpers" do
    get "/post"

    assert_response :success
    assert_select "meta[property='og:image'][content^='https://snaps.test/signed-url/image.jpg?template_id=t1&variants=']"
    assert_select "img.cover[alt='Dark Avengers'][src^='https://snaps.test/signed-url/image.jpg?template_id=t1&variants=']"
  end
end
