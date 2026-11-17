module Snapsbrew
  class Resource
    def initialize(client)
      @client = client
    end

    def inspect
      "#<#{self.class.name}>"
    end

    private
      attr_reader :client

      def get(path, **options)    = client.request(:get, path, **options)
      def post(path, **options)   = client.request(:post, path, **options)
      def patch(path, **options)  = client.request(:patch, path, **options)
      def delete(path, **options) = client.request(:delete, path, **options)

      def escape(segment)
        URI.encode_uri_component(segment.to_s)
      end

      # A cursor list: GET /v1/templates, GET /v1/screenshots. A block can
      # change each record before the page wraps it.
      def cursor_page(path, cursor: nil, &prepare)
        body = get(path, query: { cursor: }.compact)
        next_cursor = body.dig("meta", "next_cursor")

        next_page = -> { cursor_page(path, cursor: next_cursor, &prepare) } if next_cursor

        records = prepare ? body["data"].map(&prepare) : body["data"]
        Page.new(records, body["meta"], &next_page)
      end
  end
end
