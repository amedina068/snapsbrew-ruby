require "test_helper"

class Snapsbrew::ClientTest < Snapsbrew::TestCase
  def test_sends_the_token_and_json_headers
    stub = stub_api(:get, "/v1/auth")
      .with(headers: { "Authorization" => "Bearer #{TOKEN}", "Accept" => "application/json", "User-Agent" => "snapsbrew-ruby/#{Snapsbrew::VERSION}" })
      .to_return(json(data: { email: "dev@example.com" }))

    client.account

    assert_requested stub
  end

  def test_the_api_lives_under_api_of_the_instance_url
    stub = stub_request(:get, "https://snaps.test/api/v1/auth").to_return(json(data: {}))

    client(url: "https://snaps.test/").account
    client(url: "https://snaps.test/api").account

    assert_requested stub, times: 2
  end

  def test_sends_a_json_body
    stub = stub_api(:post, "/v1/tags").with(body: { name: "Launch" }.to_json, headers: { "Content-Type" => "application/json" })
      .to_return(json({ data: { id: 1 } }, status: 201))

    client.tags.create(name: "Launch")

    assert_requested stub
  end

  def test_returns_a_string_for_a_body_that_is_not_json
    stub_api(:get, "/v1/snaps/preview", query: { template_id: "t1" })
      .to_return(status: 200, body: "<!DOCTYPE html>", headers: { "Content-Type" => "text/html; charset=UTF-8" })

    assert_equal "<!DOCTYPE html>", client.snaps.preview(template: "t1")
  end

  def test_missing_url
    error = assert_raises(Snapsbrew::ConfigurationError) { Snapsbrew::Client.new(token: TOKEN).account }

    assert_match "url", error.message
  end

  def test_missing_token
    error = assert_raises(Snapsbrew::ConfigurationError) { Snapsbrew::Client.new(url: URL).account }

    assert_match "token", error.message
  end

  def test_inspect_hides_the_token_and_the_signing_key
    refute_includes client.inspect, TOKEN
    refute_includes client.inspect, "test-key"
  end
end
