module Snapsbrew
  class Error < StandardError; end

  # A setting that the call needs is missing, for example the instance URL.
  class ConfigurationError < Error; end

  # The request did not get a response: the connection failed or timed out.
  class ConnectionError < Error; end

  # The API returned a status that is not a success.
  class ApiError < Error
    attr_reader :status, :body, :request_id

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
      super(body.is_a?(Hash) && body["message"] || "Snapsbrew returned HTTP #{status}")
    end

    # The seconds to wait before the next request, from the Retry-After header.
    def retry_after
      return if @retry_after.nil?

      Integer(@retry_after, exception: false) || [ (Time.httpdate(@retry_after) - Time.now).ceil, 0 ].max
    rescue ArgumentError
      nil
    end
  end

  class AuthenticationError < ApiError; end
  class AuthorizationError < ApiError; end
  class NotFoundError < ApiError; end
  class ConflictError < ApiError; end
  class RateLimitError < ApiError; end
  class ServerError < ApiError; end

  class ValidationError < ApiError
    # The field errors, for example { "template_id" => ["The template id field is required."] }.
    def errors
      body.is_a?(Hash) && body["errors"] || {}
    end
  end
end
