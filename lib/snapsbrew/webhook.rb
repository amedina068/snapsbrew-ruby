module Snapsbrew
  # The webhook delivery is not valid. reason is :signature, :timestamp or :payload.
  class WebhookVerificationError < Error
    attr_reader :reason

    def initialize(reason, message)
      @reason = reason
      super(message)
    end
  end

  # Verifies a signed webhook delivery. Use it on the server only, because
  # the webhook secret is a secret.
  #
  #   event = Snapsbrew::Webhook.verify(request.raw_post, request.headers)
  #   event.event         # => "snap.completed"
  #   event.delivery_id   # => "3f2b6c1e-8a4d-4e5f-9b0a-1c2d3e4f5a6b"
  #
  # Give the raw body. A body that you parse and encode again has other bytes,
  # because Snapsbrew escapes "/" as \/ and each non-ASCII character as \uXXXX.
  module Webhook
    DELIVERY  = "X-Snapsbrew-Delivery"
    TIMESTAMP = "X-Snapsbrew-Timestamp"
    SIGNATURE = "X-Snapsbrew-Signature"

    # The seconds that a timestamp can be before or after the current time.
    TOLERANCE = 300

    # The events of Snapsbrew today. The app can add events, so verify accepts other names too.
    EVENTS = %w[ snap.completed snap.failed snap-import.completed snap-import.failed snap-import.canceled ].freeze

    # A verified event. All attempts of one delivery have the same delivery_id,
    # so a receiver can use it to ignore a duplicate.
    class Event < Record
      attr_reader :delivery_id

      def initialize(attributes, delivery_id:)
        super(attributes)
        @delivery_id = delivery_id
      end
    end

    # Returns the decoded event. Raises WebhookVerificationError with a reason:
    #
    # - :signature when the signature is missing or does not match the body.
    # - :timestamp when the timestamp is missing, is not Unix seconds, or is
    #   more than tolerance seconds from now.
    # - :payload when the signature is valid, but the body is not a JSON object.
    #
    # headers can be the Rails request.headers, a Rack env or a Hash. An older
    # instance sends no delivery header. Then delivery_id is nil.
    def self.verify(body, headers, secret: Snapsbrew.config.webhook_secret, tolerance: TOLERANCE, now: Time.now)
      raise ConfigurationError, "Set the Snapsbrew webhook_secret to verify a webhook" if secret.to_s.empty?

      signature = header(headers, SIGNATURE)
      timestamp = header(headers, TIMESTAMP)

      refuse :signature, "The #{SIGNATURE} header is missing" unless signature
      refuse :timestamp, "The #{TIMESTAMP} header is missing or is not Unix seconds" unless timestamp&.match?(/\A[0-9]+\z/)

      unless OpenSSL.secure_compare(sign(timestamp, body, secret), signature.downcase)
        refuse :signature, "The webhook signature does not match the body"
      end

      if (now.to_i - timestamp.to_i).abs > tolerance
        refuse :timestamp, "The webhook timestamp is more than #{tolerance} seconds from now"
      end

      Event.new(payload(body), delivery_id: header(headers, DELIVERY))
    end

    # The X-Snapsbrew-Signature value for a timestamp and a raw body.
    def self.sign(timestamp, body, secret)
      OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.".b + body.to_s.b)
    end

    # Rails and Hash headers use the header name. A Rack env uses HTTP_X_SNAPSBREW_SIGNATURE.
    # An empty value counts as a missing header.
    def self.header(headers, name)
      value = headers[name] || headers[name.downcase] || headers["HTTP_#{name.upcase.tr("-", "_")}"]
      value ||= headers.find { |key, _| key.to_s.casecmp?(name) }&.last if headers.is_a?(Hash)
      value = Array(value).first.to_s.strip

      value unless value.empty?
    end

    def self.payload(body)
      payload = JSON.parse(body)
      payload.is_a?(Hash) ? payload : refuse(:payload, "The webhook body is not a JSON object")
    rescue JSON::ParserError
      refuse :payload, "The webhook body is not JSON"
    end

    def self.refuse(reason, message)
      raise WebhookVerificationError.new(reason, message)
    end
    private_class_method :header, :payload, :refuse
  end
end
