require "test_helper"
require "tempfile"

class Snapsbrew::MediaTest < Snapsbrew::TestCase
  PNG = "\x89PNG\r\n\x1A\nimage-bytes".b

  def test_upload_a_path
    Tempfile.create([ "logo", ".png" ]) do |file|
      file.binmode
      file.write(PNG)
      file.flush

      stub = stub_api(:post, "/v1/media").with { |request| multipart?(request, File.basename(file.path)) }
        .to_return(json(id: 12, file_name: "logo.png", src: "https://snaps.test/storage/12/logo.png"))

      assert_equal "https://snaps.test/storage/12/logo.png", client.media.upload(file.path).src
      assert_requested stub
    end
  end

  def test_upload_an_uploaded_file
    upload = Struct.new(:original_filename, :content_type, :io) do
      def read = io.read
      def rewind = io.rewind
    end.new("logo.png", "image/png", StringIO.new(PNG))

    stub = stub_api(:post, "/v1/media").with { |request| multipart?(request, "logo.png") && request.body.include?("image/png") }
      .to_return(json(id: 12))

    assert_equal 12, client.media.upload(upload).id
    assert_requested stub
  end

  def test_upload_is_not_retried_after_a_server_error
    stub = stub_api(:post, "/v1/media").to_return(json({}, status: 500))

    assert_raises(Snapsbrew::ServerError) { client.media.upload(StringIO.new(PNG)) }
    assert_requested stub, times: 1
  end

  def test_list_walks_the_pages
    stub_api(:get, "/v1/media").to_return(json(data: [ { id: 2 } ], links: { next: "#{URL}/api/v1/media?page=2" }, meta: { current_page: 1 }))
    stub_api(:get, "/v1/media", query: { page: "2" }).to_return(json(data: [ { id: 1 } ], links: { next: nil }, meta: { current_page: 2 }))

    assert_equal [ 2, 1 ], client.media.map(&:id)
  end

  private
    def multipart?(request, filename)
      request.headers["Content-Type"].start_with?("multipart/form-data") &&
        request.body.include?(%(name="file"; filename="#{filename}")) &&
        request.body.b.include?(PNG)
    end
end
