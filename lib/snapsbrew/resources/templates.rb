module Snapsbrew
  class Templates < Resource
    include Enumerable

    # One page of templates. Pass the cursor of the previous page to read the next one.
    def list(cursor: nil) = cursor_page("/v1/templates", cursor:)

    # Enumerates every template, page after page.
    def each(&) = list.each_record(&)

    def find(uuid) = Record.wrap(get("/v1/templates/#{escape(uuid)}")["data"])

    # The canvas size presets, for example instagram_story and open_graph.
    def sizes = Record.wrap(get("/v1/templates/sizes")["data"])

    def create(title:, size: nil, width: nil, height: nil, layers: nil)
      Record.wrap(post("/v1/templates", json: { title:, size:, width:, height:, layers: }.compact)["data"])
    end

    def update(uuid, title:, size: nil, width: nil, height: nil, layers: nil)
      Record.wrap(patch("/v1/templates/#{escape(uuid)}", json: { title:, size:, width:, height:, layers: }.compact)["data"])
    end

    def destroy(uuid)
      delete("/v1/templates/#{escape(uuid)}")
      true
    end

    # Publishes the draft. Snaps and previews render the published version only.
    def publish(uuid)
      Record.wrap(post("/v1/templates/#{escape(uuid)}/publish", idempotent: true)["data"])
    end
  end
end
