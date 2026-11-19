require "test_helper"

class Snapsbrew::FormsTest < Snapsbrew::TestCase
  FORM_URL = "#{URL}/api/v1/embedded-forms/5c2a9e1f-0b44-4a1e-9f2b-5d3c8e1a7b60?signature=0f3a9c".freeze
  SNAP = {
    id: "9f1c2d3e", media_url: "https://snaps.test/storage/snaps/9f1c2d3e.png", width: 1200, height: 630, type: "image",
    status: "completed", is_async: false, webhook_url: nil, completed_at: "2026-05-01T12:00:03Z", last_error: nil,
    variants: [], template_id: "141e8454", template_title: "Launch card", created_at: "2026-05-01T12:00:00Z"
  }.freeze

  def test_submit_a_template_form
    stub = stub_request(:post, FORM_URL).with { |request| field?(request, "layers[headline]", "Hello") }
      .to_return(json(SNAP, status: 201))

    snap = client.forms.submit(FORM_URL, headline: "Hello")

    assert_equal "https://snaps.test/storage/snaps/9f1c2d3e.png", snap.media_url
    assert_requested stub
  end

  def test_submit_a_collection_form_returns_an_array
    stub_request(:post, FORM_URL).to_return(json([ SNAP, SNAP.merge(id: "4b8a7c6d") ], status: 201))

    snaps = client.forms.submit(FORM_URL, "141e8454__headline" => "Hello")

    assert_equal %w[ 9f1c2d3e 4b8a7c6d ], snaps.map(&:id)
  end

  def test_an_image_layer_is_a_file
    stub = stub_request(:post, FORM_URL).with do |request|
      request.body.include?(%(Content-Disposition: form-data; name="layers[photo]"; filename="photo.png")) &&
        request.body.include?("Content-Type: image/png\r\n\r\nPNG-BYTES\r\n")
    end.to_return(json(SNAP, status: 201))

    photo = StringIO.new("PNG-BYTES")
    def photo.original_filename = "photo.png"
    def photo.content_type = "image/png"

    client.forms.submit(FORM_URL, photo:)

    assert_requested stub
  end

  def test_a_pathname_is_a_file
    Dir.mktmpdir do |dir|
      path = Pathname(dir).join("logo.png")
      path.binwrite("LOGO")
      stub = stub_request(:post, FORM_URL).with { |request| request.body.include?(%(name="layers[logo]"; filename="logo.png")) }
        .to_return(json(SNAP, status: 201))

      client.forms.submit(FORM_URL, logo: path)

      assert_requested stub
    end
  end

  def test_the_form_gets_no_token
    stub = stub_request(:post, FORM_URL).with { |request| !request.headers.key?("Authorization") }.to_return(json(SNAP, status: 201))

    client.forms.submit(FORM_URL, headline: "Hello")

    assert_requested stub
  end

  def test_a_client_with_no_url_and_no_token_can_submit
    stub_request(:post, FORM_URL).to_return(json(SNAP, status: 201))

    assert_equal "9f1c2d3e", Snapsbrew::Client.new.forms.submit(FORM_URL, headline: "Hello").id
  end

  def test_the_url_must_be_absolute
    assert_raises(ArgumentError) { client.forms.submit("/api/v1/embedded-forms/5c2a", headline: "Hello") }
  end

  def test_a_bad_signature_is_a_not_found_error_with_an_empty_message
    stub_request(:post, FORM_URL).to_return(json({ message: "" }, status: 404))

    error = assert_raises(Snapsbrew::NotFoundError) { client.forms.submit(FORM_URL, headline: "Hello") }

    assert_equal "Snapsbrew returned HTTP 404", error.message
  end

  def test_a_layer_value_that_fails_a_rule
    stub_request(:post, FORM_URL).to_return(json({
      message: "The layers.bg field must be a valid color.", errors: { "layers.bg": [ "The layers.bg field must be a valid color." ] }
    }, status: 422))

    error = assert_raises(Snapsbrew::ValidationError) { client.forms.submit(FORM_URL, bg: "nope") }

    assert_equal [ "The layers.bg field must be a valid color." ], error.errors["layers.bg"]
  end

  def test_too_many_submissions
    stub_request(:post, FORM_URL).to_return(json({ message: "Too many submissions. Wait one minute, then send the form again.", code: "rate_limited" },
      status: 429, headers: { "Retry-After" => "30" }))

    error = assert_raises(Snapsbrew::RateLimitError) { client(max_retries: 0).forms.submit(FORM_URL, headline: "Hello") }

    assert_equal "rate_limited", error.code
    assert_equal 30, error.retry_after
  end

  def test_a_server_error_is_not_retried
    stub = stub_request(:post, FORM_URL).to_return(json({ message: "Server Error" }, status: 500))

    assert_raises(Snapsbrew::ServerError) { client.forms.submit(FORM_URL, headline: "Hello") }
    assert_requested stub, times: 1
  end

  def test_a_rate_limit_is_retried
    stub = stub_request(:post, FORM_URL).to_return(json({ code: "rate_limited" }, status: 429, headers: { "Retry-After" => "1" }))
      .then.to_return(json(SNAP, status: 201))

    form_client = client

    assert_equal "9f1c2d3e", form_client.forms.submit(FORM_URL, headline: "Hello").id
    assert_equal [ 1 ], form_client.pauses
    assert_requested stub, times: 2
  end

  private
    def field?(request, name, value)
      request.body.include?(%(Content-Disposition: form-data; name="#{name}"\r\n\r\n#{value}\r\n))
    end
end
