module Snapsbrew
  class Tags < Resource
    # Up to 15 tags, ordered by name.
    def list(search: nil) = Record.wrap(get("/v1/tags", query: { search: }.compact)["data"])

    def create(name:) = Record.wrap(post("/v1/tags", json: { name: })["data"])
  end
end
