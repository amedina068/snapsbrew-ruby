module Snapsbrew
  # Images of web pages. The image_url of a screenshot is nil when the
  # screenshot has no image.
  class Screenshots < Resource
    include Enumerable

    #   Snapsbrew.screenshots.create(url: "https://example.com", width: 1280, height: 720)
    def create(url:, width: nil, height: nil)
      Record.wrap(post("/v1/screenshots", json: { url:, width:, height: }.compact)["data"])
    end

    def list(cursor: nil) = cursor_page("/v1/screenshots", cursor:)

    def each(&) = list.each_record(&)

    def find(uuid) = Record.wrap(get("/v1/screenshots/#{escape(uuid)}")["data"])
  end
end
