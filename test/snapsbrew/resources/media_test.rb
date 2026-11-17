require "test_helper"
require "tempfile"

class Snapsbrew::MediaTest < Snapsbrew::TestCase
  PNG = "\x89PNG\r\n\x1A\nimage-bytes".b
  # POST /v1/media and each item of GET /v1/media send these fields and no other field.
  MEDIA_FIELDS = %w[ id uuid name file_name mime_type size original_url src created_at ].freeze

  def test_upload_a_path
    Tempfile.create([ "logo", ".png" ]) do |file|
      file.binmode
      file.write(PNG)
      file.flush

      stub = stub_api(:post, "/v1/media").with { |request| multipart?(request, File.basename(file.path)) }
        .to_return(json(media(12)))

      assert_equal "https://snaps.test/storage/12/conversions/logo-image.png", client.media.upload(file.path).src
      assert_requested stub
    end
  end

  def test_upload_an_uploaded_file
    upload = Struct.new(:original_filename, :content_type, :io) do
      def read = io.read
      def rewind = io.rewind
    end.new("logo.png", "image/png", StringIO.new(PNG))

    stub = stub_api(:post, "/v1/media").with { |request| multipart?(request, "logo.png") && request.body.include?("image/png") }
      .to_return(json(media(12)))

    assert_equal 12, client.media.upload(upload).id
    assert_requested stub
  end

  def test_upload_is_not_retried_after_a_server_error
    stub = stub_api(:post, "/v1/media").to_return(json({}, status: 500))

    assert_raises(Snapsbrew::ServerError) { client.media.upload(StringIO.new(PNG)) }
    assert_requested stub, times: 1
  end

  def test_list_walks_the_pages
    stub_api(:get, "/v1/media").to_return(json(paginator(page: 1, data: [ media(2) ], next_page_url: "#{URL}/api/v1/media?page=2")))
    stub_api(:get, "/v1/media", query: { page: "2" }).to_return(json(paginator(page: 2, data: [ media(1) ], next_page_url: nil)))

    assert_equal [ 2, 1 ], client.media.map(&:id)
  end

  def test_list_reads_the_flat_paginator
    stub_api(:get, "/v1/media").to_return(json(paginator(page: 1, data: [ media(2) ], next_page_url: nil)))

    page = client.media.list

    assert_equal "https://snaps.test/storage/2/conversions/logo-image.png", page.first.src
    assert_equal 1, page.meta.current_page
    assert_equal 1, page.meta.total
    refute page.next_page?
  end

  def test_a_media_record_has_the_nine_fields_of_the_api
    stub_api(:post, "/v1/media").to_return(json(media(12)))

    image = client.media.upload(StringIO.new(PNG))

    assert_equal MEDIA_FIELDS, image.to_h.keys
    refute_respond_to image, :model_type
    assert_nil image[:collection_name]
  end

  private
    def media(id)
      { id:, uuid: "0d4c3a1e-5b2f-4e8a-9c7d-1f2e3a4b5c6#{id}", name: "logo", file_name: "logo.png", mime_type: "image/png", size: 20480,
        original_url: "https://snaps.test/storage/#{id}/logo.png", src: "https://snaps.test/storage/#{id}/conversions/logo-image.png",
        created_at: "2026-05-01T12:00:00.000000Z" }
    end

    # The flat Laravel paginator of GET /v1/media: the page fields sit next to data, with no meta key.
    def paginator(page:, data:, next_page_url:)
      { current_page: page, data:, first_page_url: "#{URL}/api/v1/media?page=1", from: 1, last_page: 2,
        last_page_url: "#{URL}/api/v1/media?page=2", links: [ { url: nil, label: "&laquo; Previous", active: false } ],
        next_page_url:, path: "#{URL}/api/v1/media", per_page: 12, prev_page_url: nil, to: 1, total: 1 }
    end

    def multipart?(request, filename)
      request.headers["Content-Type"].start_with?("multipart/form-data") &&
        request.body.include?(%(name="file"; filename="#{filename}")) &&
        request.body.b.include?(PNG)
    end
end
