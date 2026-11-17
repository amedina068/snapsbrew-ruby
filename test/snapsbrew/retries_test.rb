require "test_helper"

class Snapsbrew::RetriesTest < Snapsbrew::TestCase
  def test_retries_a_get_after_a_server_error
    stub = stub_api(:get, "/v1/auth").to_return(json({}, status: 503)).then.to_return(json(data: { name: "Ada" }))
    client = client()

    assert_equal "Ada", client.account.name
    assert_requested stub, times: 2
    assert_equal 1, client.pauses.size
  end

  def test_stops_after_max_retries
    stub = stub_api(:get, "/v1/auth").to_return(json({}, status: 500))
    client = client(max_retries: 2)

    assert_raises(Snapsbrew::ServerError) { client.account }
    assert_requested stub, times: 3
  end

  def test_backoff_grows_and_has_jitter
    stub_api(:get, "/v1/auth").to_return(json({}, status: 500))
    client = client(max_retries: 4)

    assert_raises(Snapsbrew::ServerError) { client.account }

    client.pauses.zip([ 0.5, 1, 2, 4 ]).each do |pause, backoff|
      assert_operator pause, :>=, backoff / 2.0
      assert_operator pause, :<=, backoff
    end
  end

  def test_never_retries_a_post_after_a_server_error
    stub = stub_api(:post, "/v1/snaps").to_return(json({ message: "Render failed." }, status: 500))

    assert_raises(Snapsbrew::ServerError) { client.snaps.create(template: "t1") }
    assert_requested stub, times: 1
  end

  def test_retries_a_post_with_an_idempotency_key_after_a_server_error
    stub = stub_api(:post, "/v1/snaps").to_return(json({}, status: 500)).then.to_return(json({ id: "s1" }, status: 201))

    assert_equal "s1", client.snaps.create(template: "t1", idempotency_key: "order-1").id
    assert_requested stub, times: 2
  end

  def test_retries_a_post_after_a_rate_limit_and_waits_for_retry_after
    stub = stub_api(:post, "/v1/snaps")
      .to_return(json({ message: "Too Many Attempts." }, status: 429, headers: { "Retry-After" => "7" }))
      .then.to_return(json({ id: "s1" }, status: 201))
    client = client()

    assert_equal "s1", client.snaps.create(template: "t1").id
    assert_requested stub, times: 2
    assert_equal [ 7 ], client.pauses
  end

  def test_does_not_wait_for_a_long_retry_after
    stub = stub_api(:get, "/v1/auth").to_return(json({}, status: 429, headers: { "Retry-After" => "3600" }))

    error = assert_raises(Snapsbrew::RateLimitError) { client.account }
    assert_equal 3600, error.retry_after
    assert_requested stub, times: 1
  end

  def test_retries_a_post_after_a_connection_error_before_the_request_was_sent
    stub = stub_api(:post, "/v1/screenshots").to_raise(Errno::ECONNREFUSED).then.to_timeout
      .then.to_return(json(data: { id: "a1" }))

    assert_equal "a1", client.screenshots.create(url: "https://example.com").id
    assert_requested stub, times: 3
  end

  def test_never_retries_a_post_after_the_server_possibly_received_it
    stub = stub_api(:post, "/v1/snaps").to_raise(Net::ReadTimeout)

    assert_raises(Snapsbrew::ConnectionError) { client.snaps.create(template: "t1") }
    assert_requested stub, times: 1
  end

  def test_retries_a_get_after_a_read_timeout
    stub = stub_api(:get, "/v1/auth").to_raise(Net::ReadTimeout).then.to_return(json(data: {}))

    client.account

    assert_requested stub, times: 2
  end

  def test_never_retries_a_client_error
    stub = stub_api(:get, "/v1/templates/missing").to_return(json({ message: "Not found." }, status: 404))

    assert_raises(Snapsbrew::NotFoundError) { client.templates.find("missing") }
    assert_requested stub, times: 1
  end

  def test_max_retries_zero_turns_retries_off
    stub = stub_api(:get, "/v1/auth").to_return(json({}, status: 503))

    assert_raises(Snapsbrew::ServerError) { client(max_retries: 0).account }
    assert_requested stub, times: 1
  end
end
