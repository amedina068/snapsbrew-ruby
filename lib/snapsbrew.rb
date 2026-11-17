require "json"
require "net/http"
require "openssl"
require "securerandom"
require "time"
require "uri"

require "snapsbrew/version"
require "snapsbrew/errors"
require "snapsbrew/configuration"
require "snapsbrew/record"
require "snapsbrew/page"
require "snapsbrew/variants"
require "snapsbrew/signed_url"
require "snapsbrew/resource"
require "snapsbrew/resources/guides"
require "snapsbrew/resources/templates"
require "snapsbrew/resources/snaps"
require "snapsbrew/resources/batches"
require "snapsbrew/resources/screenshots"
require "snapsbrew/resources/media"
require "snapsbrew/resources/tags"
require "snapsbrew/client"

# A client for one Snapsbrew instance.
#
#   Snapsbrew.configure do |config|
#     config.url   = "https://snaps.example.com"
#     config.token = "..."
#   end
#
#   Snapsbrew.snaps.create(template: id, variants: { title: "Hello" })
#   Snapsbrew.signed_url(template: id, title: "Hello")
module Snapsbrew
  class << self
    def configure
      yield config
      reset!
    end

    def config
      @config ||= Configuration.new
    end

    def client
      @client ||= Client.new(**config.to_h)
    end

    def reset!
      @client = nil
    end

    def account      = client.account
    def guides       = client.guides
    def templates    = client.templates
    def snaps        = client.snaps
    def batches      = client.batches
    def screenshots  = client.screenshots
    def media        = client.media
    def tags         = client.tags

    def signed_url(...) = client.signed_url(...)
  end
end

require "snapsbrew/railtie" if defined?(Rails::Railtie)
