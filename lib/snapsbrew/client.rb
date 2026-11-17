module Snapsbrew
  # A client for one Snapsbrew instance. Snapsbrew.client is the default
  # client, built from Snapsbrew.config. Make your own to talk to more than one
  # instance:
  #
  #   client = Snapsbrew::Client.new(url: "https://snaps.example.com", token: "...")
  #   client.templates.list
  class Client
    # The request did not reach the server, so a retry cannot render twice.
    BEFORE_SEND = [ Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ENETUNREACH, SocketError, Net::OpenTimeout ].freeze

    # The server possibly received the request.
    AFTER_SEND = [ Net::ReadTimeout, Net::WriteTimeout, Errno::ECONNRESET, Errno::EPIPE, Errno::ETIMEDOUT, EOFError ].freeze

    BASE_DELAY = 0.5
    MAX_DELAY = 8
    MAX_RETRY_AFTER = 60

    attr_reader :url, :timeout, :max_retries

    def initialize(url: nil, token: nil, signing_key: nil, timeout: 60, max_retries: 2)
      @url = url.to_s.chomp("/").delete_suffix("/api")
      @token = token
      @signing_key = signing_key
      @timeout = timeout
      @max_retries = max_retries
    end

    # The account of the token: email, name and company.
    def account = Record.wrap(request(:get, "/v1/auth")["data"])

    def guides      = @guides ||= Guides.new(self)
    def templates   = @templates ||= Templates.new(self)
    def snaps       = @snaps ||= Snaps.new(self)
    def batches     = @batches ||= Batches.new(self)
    def screenshots = @screenshots ||= Screenshots.new(self)
    def media       = @media ||= Media.new(self)
    def tags        = @tags ||= Tags.new(self)

    #   client.signed_url(template: id, title: "Hello", cover: "https://example.com/a.jpg")
    def signed_url(**options)
      SignedUrl.new(url:, key: @signing_key).build(**options)
    end

    # Sends one request to the API and returns the parsed body.
    #
    # Retries a 429 and a connection error that happened before the request
    # reached the server. Retries a 5xx and a later connection error only when
    # the request is idempotent. Retries a 409 with the code
    # idempotency_key_in_progress for an idempotent request. Only a request
    # with an idempotency key gets this code.
    def request(method, path, query: nil, json: nil, form: nil, idempotent: method == :get)
      attempt = 0

      begin
        attempt += 1
        response = transmit(method, path, query:, json:, form:)
        raise ApiError.for(response) unless response.is_a?(Net::HTTPSuccess)

        parse(response)
      rescue RateLimitError, ServerError, ConflictError => error
        raise unless attempt <= max_retries && retryable?(error, idempotent)

        pause delay(attempt, error.retry_after)
        retry
      rescue *BEFORE_SEND, *AFTER_SEND => error
        unless attempt <= max_retries && (idempotent || BEFORE_SEND.any? { |kind| error.is_a?(kind) })
          raise ConnectionError, "Snapsbrew request failed: #{error.message}"
        end

        pause delay(attempt)
        retry
      rescue OpenSSL::SSL::SSLError => error
        raise ConnectionError, "Snapsbrew request failed: #{error.message}"
      end
    end

    def inspect
      "#<#{self.class.name} url=#{url.inspect}>"
    end

    private
      def transmit(method, path, query:, json:, form:)
        raise ConfigurationError, "Set the Snapsbrew url, for example https://snaps.example.com" if url.empty?
        raise ConfigurationError, "Set the Snapsbrew token" if @token.to_s.empty?

        uri = URI("#{url}/api#{path}")
        uri.query = to_query(query) if query && !query.empty?

        request = Net::HTTP.const_get(method.to_s.capitalize).new(uri)
        request["Authorization"] = "Bearer #{@token}"
        request["Accept"] = "application/json"
        request["User-Agent"] = "snapsbrew-ruby/#{VERSION}"

        if json
          request["Content-Type"] = "application/json"
          request.body = JSON.generate(json)
        elsif form
          boundary = "snapsbrew-#{SecureRandom.hex(16)}"
          request["Content-Type"] = "multipart/form-data; boundary=#{boundary}"
          request.body = multipart(form, boundary)
        end

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                        open_timeout: timeout, read_timeout: timeout, write_timeout: timeout) do |http|
          http.request(request)
        end
      end

      # Net::HTTP#set_form streams the body, so it cannot replay it on a retry.
      # A String body can be sent again.
      def multipart(form, boundary)
        form.each_with_object(String.new(encoding: Encoding::BINARY)) do |(name, (data, options)), body|
          body << "--#{boundary}\r\n"
          body << %(Content-Disposition: form-data; name="#{name}"; filename="#{options[:filename].to_s.delete("\"\r\n")}"\r\n).b
          body << "Content-Type: #{options[:content_type] || "application/octet-stream"}\r\n\r\n"
          body << data.b << "\r\n"
        end << "--#{boundary}--\r\n"
      end

      def parse(response)
        body = response.body.to_s
        return body unless response.content_type.to_s.include?("json")

        body.empty? ? {} : JSON.parse(body)
      end

      def retryable?(error, idempotent)
        case error
        when RateLimitError then error.retry_after.nil? || error.retry_after <= MAX_RETRY_AFTER
        when ServerError    then idempotent
        when ConflictError  then idempotent && error.in_progress?
        end
      end

      # Exponential backoff with jitter. A Retry-After value wins.
      def delay(attempt, retry_after = nil)
        return retry_after if retry_after

        backoff = [ BASE_DELAY * (2**(attempt - 1)), MAX_DELAY ].min
        backoff / 2 + rand * backoff / 2
      end

      def pause(seconds)
        sleep seconds
      end

      # Builds a query string in the nested form that Laravel reads, for example
      # variants[0][layer]=title&variants[0][text]=Hello.
      def to_query(value, prefix = nil)
        case value
        when Hash
          value.filter_map { |key, item| to_query(item, prefix ? "#{prefix}[#{key}]" : key.to_s) unless item.nil? }.join("&")
        when Array
          value.each_with_index.map { |item, index| to_query(item, "#{prefix}[#{index}]") }.join("&")
        when true, false
          "#{URI.encode_www_form_component(prefix)}=#{value ? 1 : 0}"
        else
          "#{URI.encode_www_form_component(prefix)}=#{URI.encode_www_form_component(value.to_s)}"
        end
      end
  end
end
