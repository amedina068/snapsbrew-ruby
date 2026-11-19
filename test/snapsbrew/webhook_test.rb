require "test_helper"

class Snapsbrew::WebhookTest < Snapsbrew::TestCase
  VECTORS = JSON.parse(File.read(File.expand_path("../fixtures/webhook-vectors.json", __dir__)))
  SECRET = "whsec_test0123456789abcdefghijklmnopqrstuvwxyz"

  VECTORS["cases"].each do |vector|
    define_method("test_vector_#{vector["name"].gsub(/\W+/, "_")}") do
      verify = -> { Snapsbrew::Webhook.verify(vector["body"], vector["headers"], secret: VECTORS["secret"], now: VECTORS["now"]) }

      if vector["valid"]
        event = verify.call

        assert_equal JSON.parse(vector["body"]), event.to_h
        assert_equal vector["headers"]["X-Snapsbrew-Delivery"], event.delivery_id
      else
        assert_raises(Snapsbrew::WebhookVerificationError) { verify.call }
      end
    end
  end

  def test_a_valid_vector_is_refused_at_the_current_time
    vector = VECTORS["cases"].first

    error = assert_raises(Snapsbrew::WebhookVerificationError) do
      Snapsbrew::Webhook.verify(vector["body"], vector["headers"], secret: VECTORS["secret"])
    end
    assert_equal :timestamp, error.reason
  end

  def test_the_vectors_use_the_default_tolerance
    assert_equal VECTORS["tolerance_seconds"], Snapsbrew::Webhook::TOLERANCE
  end

  def test_returns_the_event_as_a_record
    event = verify(delivery("snap.completed", snap: { id: "9f1c2d3e", media_url: "https://snaps.test/a.png" }))

    assert_equal "snap.completed", event.event
    assert_equal "https://snaps.test/a.png", event.snap.media_url
  end

  def test_a_failed_snap
    event = verify(delivery("snap.failed", snap: { status: "failed", last_error: "render_failed", media_url: "" }))

    assert_equal "snap.failed", event.event
    assert_equal "render_failed", event.snap.last_error
    assert_equal "", event.snap.media_url
  end

  def test_the_events_include_snap_failed
    assert_equal %w[ snap.completed snap.failed snap-import.completed snap-import.failed snap-import.canceled ], Snapsbrew::Webhook::EVENTS
  end

  def test_accepts_an_unknown_event
    assert_equal "snap.archived", verify(delivery("snap.archived")).event
  end

  def test_the_delivery_id_is_nil_without_the_header
    body, headers = delivery("snap.completed")

    assert_nil verify([ body, headers.except("X-Snapsbrew-Delivery") ]).delivery_id
  end

  def test_the_tolerance_can_change
    body, headers = delivery("snap.completed", timestamp: 1_000)

    assert verify([ body, headers ], tolerance: 600, now: 1_500)

    error = assert_raises(Snapsbrew::WebhookVerificationError) { verify([ body, headers ], tolerance: 60, now: 1_500) }
    assert_equal :timestamp, error.reason
  end

  def test_a_timestamp_in_the_future_is_refused
    body, headers = delivery("snap.completed", timestamp: 2_000)

    error = assert_raises(Snapsbrew::WebhookVerificationError) { verify([ body, headers ], now: 1_000) }
    assert_equal :timestamp, error.reason
  end

  def test_now_can_be_a_time
    body, headers = delivery("snap.completed", timestamp: 1_000)

    assert verify([ body, headers ], now: Time.at(1_100))
  end

  def test_reads_rack_env_headers
    body, headers = delivery("snap.completed")
    env = headers.to_h { |name, value| [ "HTTP_#{name.upcase.tr("-", "_")}", value ] }

    assert_equal "3f2b6c1e-8a4d-4e5f-9b0a-1c2d3e4f5a6b", Snapsbrew::Webhook.verify(body, env, secret: SECRET).delivery_id
  end

  def test_reads_lowercase_headers
    body, headers = delivery("snap.completed")

    assert verify([ body, headers.transform_keys(&:downcase) ])
  end

  def test_missing_headers_fail_on_the_signature
    error = assert_raises(Snapsbrew::WebhookVerificationError) { Snapsbrew::Webhook.verify("{}", {}, secret: SECRET) }

    assert_equal :signature, error.reason
  end

  def test_a_timestamp_that_is_not_a_number_fails_on_the_timestamp
    body = %({"event":"snap.completed"})
    headers = { "X-Snapsbrew-Timestamp" => "soon", "X-Snapsbrew-Signature" => Snapsbrew::Webhook.sign("soon", body, SECRET) }

    error = assert_raises(Snapsbrew::WebhookVerificationError) { Snapsbrew::Webhook.verify(body, headers, secret: SECRET) }
    assert_equal :timestamp, error.reason
  end

  def test_a_binary_body_with_utf8_bytes
    body = %({"event":"snap.completed","title":"¿Launch card?"}).b
    timestamp = Time.now.to_i.to_s
    headers = { "X-Snapsbrew-Timestamp" => timestamp, "X-Snapsbrew-Signature" => Snapsbrew::Webhook.sign(timestamp, body, SECRET) }

    assert_equal "¿Launch card?", Snapsbrew::Webhook.verify(body, headers, secret: SECRET).title
  end

  def test_the_secret_defaults_to_the_configuration
    config = Snapsbrew.instance_variable_get(:@config)
    Snapsbrew.instance_variable_set(:@config, nil)
    Snapsbrew.config.webhook_secret = SECRET

    assert Snapsbrew::Webhook.verify(*delivery("snap.completed"))
  ensure
    Snapsbrew.instance_variable_set(:@config, config)
  end

  def test_a_missing_secret_is_a_configuration_error
    assert_raises(Snapsbrew::ConfigurationError) { Snapsbrew::Webhook.verify(*delivery("snap.completed"), secret: nil) }
  end

  private
    def delivery(event, timestamp: Time.now.to_i, **fields)
      body = JSON.generate(event:, **fields)
      headers = {
        "X-Snapsbrew-Delivery" => "3f2b6c1e-8a4d-4e5f-9b0a-1c2d3e4f5a6b",
        "X-Snapsbrew-Timestamp" => timestamp.to_s,
        "X-Snapsbrew-Signature" => Snapsbrew::Webhook.sign(timestamp, body, SECRET)
      }

      [ body, headers ]
    end

    def verify((body, headers), secret: SECRET, **options)
      Snapsbrew::Webhook.verify(body, headers, secret:, **options)
    end
end
