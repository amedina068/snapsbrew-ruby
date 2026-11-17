module Snapsbrew
  # The static reference catalogs. The content is the same for every account,
  # so you can cache it.
  class Guides < Resource
    def design             = Record.wrap(get("/v1/guides/design")["data"])
    def layers             = Record.wrap(get("/v1/guides/layers")["data"])
    def variant_properties = Record.wrap(get("/v1/guides/variant-properties")["data"])
    def editor_document    = Record.wrap(get("/v1/guides/editor-document")["data"])
    def platforms          = Record.wrap(get("/v1/guides/platforms")["data"])
    def purposes           = Record.wrap(get("/v1/guides/purposes")["data"])

    # Snapsbrew.guides.platform(:instagram)
    def platform(key) = Record.wrap(get("/v1/guides/platforms/#{escape(key)}")["data"])

    # Snapsbrew.guides.purpose(:link_preview)
    def purpose(key) = Record.wrap(get("/v1/guides/purposes/#{escape(key)}")["data"])
  end
end
