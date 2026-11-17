module Snapsbrew
  class Snaps < Resource
    # Renders a snap and returns it. Give a template or a collection.
    #
    #   Snapsbrew.snaps.create(template: id, variants: { title: "Hello", cover: url })
    #
    # A collection returns an Array of snaps, one for each template.
    # With an idempotency_key, the client also retries the request after a
    # server error or a timeout.
    def create(template: nil, collection: nil, variants: nil, type: nil, format: nil, transparent: nil,
               async: nil, webhook_url: nil, idempotency_key: nil)
      body = {
        template_id: template, collection_id: collection, variants: Variants.normalize(variants),
        type:, format:, transparent:, async:, webhook_url:, idempotency_key:
      }.compact

      Record.wrap(post("/v1/snaps", json: body, idempotent: !idempotency_key.nil?))
    end

    # Returns the watermarked HTML preview of a snap. A preview costs no credit.
    def preview(template:, variants: nil)
      get("/v1/snaps/preview", query: { template_id: template, variants: Variants.normalize(variants) }.compact)
    end
  end
end
