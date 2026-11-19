module Snapsbrew
  class Templates < Resource
    include Enumerable

    # One page of templates. Pass the cursor of the previous page to read the next one.
    def list(cursor: nil) = cursor_page("/v1/templates", cursor:) { |template| with_modification_maps(template) }

    # Enumerates every template, page after page.
    def each(&) = list.each_record(&)

    def find(uuid) = Record.wrap(with_modification_maps(get("/v1/templates/#{escape(uuid)}")["data"]))

    # The canvas size presets, for example instagram_story and open_graph.
    def sizes = Record.wrap(get("/v1/templates/sizes")["data"])

    # groups are the editor layer groups, for example [ { id: "header", name: "Header", order: 0 } ].
    def create(title:, size: nil, width: nil, height: nil, layers: nil, groups: nil)
      Record.wrap(post("/v1/templates", json: { title:, size:, width:, height:, layers:, groups: }.compact)["data"])
    end

    # Changes only the fields that you give. Give groups: [] to remove the groups.
    def update(uuid, title:, size: nil, width: nil, height: nil, layers: nil, groups: nil)
      Record.wrap(patch("/v1/templates/#{escape(uuid)}", json: { title:, size:, width:, height:, layers:, groups: }.compact)["data"])
    end

    # Also removes the snaps, images, versions and forms of the template.
    def destroy(uuid)
      delete("/v1/templates/#{escape(uuid)}")
      true
    end

    # Publishes the draft. Snaps and previews render the published version only.
    def publish(uuid)
      Record.wrap(post("/v1/templates/#{escape(uuid)}/publish", idempotent: true)["data"])
    end

    private
      # A layer with no override returns available_modifications as [], the PHP
      # form of an empty map. Read it as an empty map, the same type as the other layers.
      def with_modification_maps(template)
        return template unless template["layers"]

        layers = template["layers"].map do |layer|
          layer["available_modifications"] == [] ? layer.merge("available_modifications" => {}) : layer
        end

        template.merge("layers" => layers)
      end
  end
end
