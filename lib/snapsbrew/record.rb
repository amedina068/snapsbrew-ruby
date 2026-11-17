module Snapsbrew
  # A response object. Read a field as a method or with [].
  #
  #   snap.media_url
  #   snap[:media_url]
  class Record
    def self.wrap(value)
      case value
      when Hash  then new(value)
      when Array then value.map { |item| wrap(item) }
      else value
      end
    end

    def initialize(attributes)
      @attributes = attributes.transform_keys(&:to_s)
    end

    def [](key)
      Record.wrap(@attributes[key.to_s])
    end

    def key?(key)
      @attributes.key?(key.to_s)
    end

    def to_h
      @attributes
    end

    def ==(other)
      other.is_a?(Record) && other.to_h == to_h
    end

    def inspect
      "#<Snapsbrew::Record #{@attributes.inspect}>"
    end

    private
      def method_missing(name, *args)
        key?(name) && args.empty? ? self[name] : super
      end

      def respond_to_missing?(name, include_private = false)
        key?(name) || super
      end
  end
end
