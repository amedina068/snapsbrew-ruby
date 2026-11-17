$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "snapsbrew"
require "minitest/autorun"
require "webmock/minitest"

module Snapsbrew
  class TestCase < Minitest::Test
    URL = "https://snaps.test"
    TOKEN = "test-token"

    def setup
      WebMock.disable_net_connect!
    end

    # A client that records each pause instead of sleeping.
    def client(**options)
      Client.new(url: URL, token: TOKEN, signing_key: "test-key", **options).tap do |client|
        client.instance_variable_set(:@pauses, [])
        def client.pauses = @pauses
        def client.pause(seconds) = @pauses << seconds
      end
    end

    def stub_api(method, path, query: nil)
      stub = stub_request(method, "#{URL}/api#{path}")
      query ? stub.with(query:) : stub
    end

    def json(body = nil, status: 200, headers: {}, **fields)
      { status:, body: JSON.generate(body || fields), headers: { "Content-Type" => "application/json", **headers } }
    end
  end
end
