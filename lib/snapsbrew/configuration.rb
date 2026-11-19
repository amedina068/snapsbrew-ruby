module Snapsbrew
  # The settings of the default client. Each value falls back to an environment
  # variable: SNAPSBREW_URL, SNAPSBREW_TOKEN, SNAPSBREW_SIGNING_KEY and SNAPSBREW_WEBHOOK_SECRET.
  # In a Rails app, the Railtie also reads Rails.application.credentials.snapsbrew.
  class Configuration
    attr_writer :url, :token, :signing_key, :webhook_secret
    attr_accessor :timeout, :max_retries

    def initialize
      @timeout = 60
      @max_retries = 2
    end

    def url            = @url || ENV["SNAPSBREW_URL"]
    def token          = @token || ENV["SNAPSBREW_TOKEN"]
    def signing_key    = @signing_key || ENV["SNAPSBREW_SIGNING_KEY"]
    def webhook_secret = @webhook_secret || ENV["SNAPSBREW_WEBHOOK_SECRET"]

    # Copies the known keys of a Hash, for example the snapsbrew credentials.
    def merge!(settings)
      settings.to_h.each do |key, value|
        public_send("#{key}=", value) if respond_to?("#{key}=")
      end
      self
    end

    # The settings of a client. The webhook secret is not one of them.
    def to_h
      { url:, token:, signing_key:, timeout:, max_retries: }
    end

    def inspect
      "#<#{self.class.name} url=#{url.inspect} timeout=#{timeout} max_retries=#{max_retries}>"
    end
  end
end
