module Snapsbrew
  # Turns the variants that you write into the array that the API reads.
  #
  # A Hash maps each layer key to one override:
  #
  #   { title: "Hello" }                       # text
  #   { cover: "https://example.com/a.jpg" }   # image_url (an http or https URL)
  #   { badge: false }                         # hidden
  #   { bg: { background_color: "#f0573f" } }  # any other override
  #
  # An Array is the API form and passes through unchanged:
  #
  #   [ { layer: "title", text: "Hello" } ]
  module Variants
    URL = %r{\Ahttps?://\S+\z}

    def self.normalize(variants)
      case variants
      when nil   then nil
      when Array then variants
      when Hash  then variants.map { |layer, value| override(layer, value) }
      else raise ArgumentError, "Give variants as a Hash or an Array, not #{variants.class}"
      end
    end

    # Joins an explicit variants argument and keyword layers into one list.
    # Returns nil when both are empty.
    def self.merge(variants, layers)
      list = Array(normalize(variants)) + Array(normalize(layers))
      list unless list.empty?
    end

    def self.override(layer, value)
      case value
      when Hash            then { layer: layer.to_s, **value }
      when false, nil      then { layer: layer.to_s, hidden: true }
      when URI::HTTP       then { layer: layer.to_s, image_url: value.to_s }
      when URL             then { layer: layer.to_s, image_url: value }
      else                      { layer: layer.to_s, text: value.to_s }
      end
    end
    private_class_method :override
  end
end
