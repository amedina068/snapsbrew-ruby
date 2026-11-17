module Snapsbrew
  class Tags < Resource
    # Up to 15 tags, ordered by name.
    def list(search: nil) = Record.wrap(get("/v1/tags", query: { search: }.compact)["data"])

    def create(name:) = Record.wrap(post("/v1/tags", json: { name: })["data"])

    # Replaces every tag of a template. Give an empty list to remove all tags.
    def sync(template:, tag_ids:)
      Record.wrap(post("/v1/templates/#{escape(template)}/tags", json: { tag_ids: }, idempotent: true)["tags"])
    end
  end
end
