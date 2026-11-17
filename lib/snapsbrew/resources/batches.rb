module Snapsbrew
  # A batch renders up to 100 snaps from one template in the background.
  class Batches < Resource
    #   Snapsbrew.batches.create(template: id, items: [
    #     { identifier: "row-1", variants: { title: "Hello" } },
    #     { identifier: "row-2", variants: { title: "World" } }
    #   ])
    def create(template:, items:, title: nil, webhook_url: nil, type: nil, format: nil, transparent: nil,
               idempotency_key: nil)
      items = items.map { |item| item.merge(variants: Variants.normalize(item[:variants] || item["variants"])).compact }
      body = { template_id: template, items:, title:, webhook_url:, type:, format:, transparent:, idempotency_key: }.compact

      Record.wrap(post("/v1/snaps/batches", json: body, idempotent: !idempotency_key.nil?))
    end

    def find(uuid) = Record.wrap(get("/v1/snaps/batches/#{escape(uuid)}"))

    # Stops the items that did not start. A second cancel changes nothing.
    def cancel(uuid) = Record.wrap(post("/v1/snaps/batches/#{escape(uuid)}/cancel", idempotent: true))
  end
end
