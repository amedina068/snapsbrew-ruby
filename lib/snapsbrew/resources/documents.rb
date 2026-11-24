module Snapsbrew
  # The v2 editor document of a template: its layers, its groups and each
  # design property. Each write is a compare-and-swap. Read the document, keep
  # its revision, and send that revision with the write. If another write moved
  # the revision, the write raises a ConflictError with current_revision and
  # current_document. The client does not retry a write.
  #
  #   draft = Snapsbrew.documents.find(id)
  #   Snapsbrew.documents.apply(id, revision: draft.revision, operations: [
  #     { operation: "set_layer_property", layer_key: "headline", property: "fontWeight", value: 700 }
  #   ])
  class Documents < Resource
    # The document and its revision. A template with no draft has a nil document and the revision 0.
    def find(uuid) = Record.wrap(get(document_path(uuid)))

    # Replaces the whole document. A layer or a property that you leave out is removed.
    # A repeat after a lost response gets a 409, because the first write
    # changed the revision. So the SDK never retries it after a 5xx.
    def replace(uuid, revision:, document:)
      Record.wrap(put(document_path(uuid), json: { revision:, document: }, idempotent: false))
    end

    # Applies 1 to 100 operations: set_layer_property and set_layer_type. They apply together, or none applies.
    def apply(uuid, revision:, operations:)
      Record.wrap(patch(document_path(uuid), json: { revision:, operations: }))
    end

    # The known problems of the stored draft. An empty issues list means that the known checks pass.
    def preflight(uuid) = Record.wrap(get("#{document_path(uuid)}/preflight"))

    private
      def document_path(uuid) = "/v1/templates/#{escape(uuid)}/document"
  end
end
