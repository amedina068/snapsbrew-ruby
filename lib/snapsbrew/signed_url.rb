module Snapsbrew
  # Builds a signed image URL. The URL renders a snap from a plain <img src>
  # or an og:image tag, with no API call.
  #
  # The signing key is a secret. Build signed URLs on the server only.
  class SignedUrl
    PATH = "/signed-url/image.jpg"

    def self.canonical(params)
      params.reject { |key, _| key.to_s == "signature" }
        .sort_by { |key, _| key.to_s.b }
        .map { |key, value| "#{key}=#{value}" }
        .join("&")
    end

    def self.sign(params, key)
      OpenSSL::HMAC.hexdigest("SHA256", key, canonical(params))
    end

    def initialize(url:, key:)
      raise ConfigurationError, "Set the Snapsbrew url to build a signed URL" if url.to_s.empty?
      raise ConfigurationError, "Set the Snapsbrew signing_key to build a signed URL" if key.to_s.empty?

      @url = url.to_s.chomp("/")
      @key = key
    end

    def build(template:, variants: nil, format: nil, transparent: nil, **layers)
      variants = Variants.merge(variants, layers)

      params = { "template_id" => template.to_s }
      params["format"] = format.to_s if format
      params["transparent"] = transparent.to_s unless transparent.nil?
      params["variants"] = [ JSON.generate(variants) ].pack("m0") if variants
      params["signature"] = self.class.sign(params, @key)

      "#{@url}#{PATH}?#{params.map { |key, value| "#{key}=#{URI.encode_uri_component(value)}" }.join("&")}"
    end

    def inspect
      "#<#{self.class.name} url=#{@url.inspect}>"
    end
  end
end
