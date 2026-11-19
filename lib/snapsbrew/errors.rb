module Snapsbrew
  class Error < StandardError; end

  # A setting that the call needs is missing, for example the instance URL.
  class ConfigurationError < Error; end

  # The request did not get a response: the connection failed or timed out.
  class ConnectionError < Error; end

  # The API returned a status that is not a success. Some bodies carry a code,
  # for example idempotency_key_in_progress on a 409 or internal_error on a 500.
  class ApiError < Error
    attr_reader :status, :body, :request_id, :code

    def self.for(response)
      body = parse(response.body)
      class_for(response.code.to_i).new(response, body)
    end

    def self.class_for(status)
      case status
      when 401 then AuthenticationError
      when 403 then AuthorizationError
      when 404 then NotFoundError
      when 409 then ConflictError
      when 422 then ValidationError
      when 429 then RateLimitError
      when 500.. then ServerError
      else ApiError
      end
    end

    def self.parse(body)
      JSON.parse(body.to_s)
    rescue JSON::ParserError
      body
    end
    private_class_method :parse

    def initialize(response, body)
      @status = response.code.to_i
      @body = body
      @request_id = response["X-Request-Uuid"]
      @retry_after = response["Retry-After"]
      @code = field("code")

      # An embedded form with a bad signature returns an empty message.
      message = field("message").to_s
      super(message.empty? ? [ "Snapsbrew returned HTTP #{status}", code ].compact.join(": ") : message)
    end

    # The seconds to wait before the next request, from the Retry-After header.
    def retry_after
      return if @retry_after.nil?

      Integer(@retry_after, exception: false) || [ (Time.httpdate(@retry_after) - Time.now).ceil, 0 ].max
    rescue ArgumentError
      nil
    end

    private
      # A body that is not JSON, for example the HTML of a proxy, has no fields.
      def field(name)
        body[name] if body.is_a?(Hash)
      end
  end

  class AuthenticationError < ApiError; end

  # A 403. A token without the api_requests ability gets the message
  # "Invalid ability provided." on each endpoint.
  class AuthorizationError < ApiError; end

  # A 404. Do not read the message to know the cause. A missing record
  # returns a message from the framework, for example "No query results for model [...]".
  class NotFoundError < ApiError
    # The valid keys of an unknown platform or purpose guide, for example ["instagram", "facebook"].
    # Empty for each other 404.
    def available
      field("available") || []
    end
  end

  class ServerError < ApiError; end

  class RateLimitError < ApiError
    def initialize(response, body)
      @limit = response["X-RateLimit-Limit"]
      super
    end

    # The requests that the endpoint allows in one minute, from the X-RateLimit-Limit header.
    # The preview endpoints allow fewer requests than the other endpoints.
    def limit
      Integer(@limit, exception: false) if @limit
    end
  end

  # A 409. Read code to know the cause:
  #
  # - idempotency_key_in_progress: another request holds the idempotency key. The client retries this case.
  # - idempotency_key_belongs_to_snap: a single snap owns the key. Send the batch with a new key.
  # - idempotency_key_belongs_to_batch: a batch owns the key. Send the snap with a new key.
  # - legacy_edit_rejected_for_v2: the template uses the v2 editor document, so templates.update cannot change it.
  # - editor_document_conflict: another write changed the editor document. Read current_revision and current_document.
  class ConflictError < ApiError
    def in_progress?
      code == "idempotency_key_in_progress"
    end

    # The stored revision of the editor document, or nil for each other conflict.
    def current_revision = field("current_revision")

    # The stored editor document as a Record, or nil for each other conflict.
    def current_document = Record.wrap(field("current_document"))
  end

  # A 422. Most bodies have field errors. An editor operation error has a code
  # and no field errors, for example editor_operation_layer_not_found.
  class ValidationError < ApiError
    # The field errors, for example { "template_id" => ["The template id field is required."] }.
    def errors
      field("errors") || {}
    end
  end
end
