module Snapsbrew
  # The image library of your account. Use a media src as an image_url variant.
  class Media < Resource
    include Enumerable

    # Uploads an image. Give a path, a File, or an uploaded file from a form.
    #
    #   Snapsbrew.media.upload("logo.png")
    #   Snapsbrew.media.upload(params[:logo])
    def upload(file)
      Record.wrap(post("/v1/media", form: { "file" => file_part(file) }))
    end

    # One page of media, 12 for each page, newest first.
    def list(page: nil)
      body = get("/v1/media", query: { page: }.compact)
      current = body.dig("meta", "current_page") || page || 1

      next_page = -> { list(page: current + 1) } if body.dig("links", "next")

      Page.new(body["data"], body["meta"], &next_page)
    end

    def each(&) = list.each_record(&)

    private
      def file_part(file)
        return File.open(file, "rb") { |opened| file_part(opened) } unless file.respond_to?(:read)

        filename = if file.respond_to?(:original_filename) then file.original_filename
        elsif file.respond_to?(:path) then File.basename(file.path)
        else "image"
        end
        content_type = file.content_type if file.respond_to?(:content_type)
        file.rewind if file.respond_to?(:rewind)

        [ file.read, { filename:, content_type: }.compact ]
      end
  end
end
