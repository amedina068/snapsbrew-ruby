module Snapsbrew
  # Submits an embedded form. A form renders on the account of its owner, so
  # it needs no token. Copy the submit URL of the form from your instance. The
  # URL carries its own signature.
  #
  #   Snapsbrew.forms.submit(submit_url, headline: "Hello", photo: params[:photo])
  #
  # A template form returns one snap. A collection form returns an Array of
  # snaps, and its layer keys are "{template uuid}__{layer key}".
  class Forms < Resource
    # Give text as a String. Give an image as a File, a Pathname or an uploaded file.
    def submit(url, layers = {})
      unless url.to_s.match?(%r{\Ahttps?://})
        raise ArgumentError, "Give the signed submit URL of the form, for example https://snaps.example.com/api/v1/embedded-forms/...?signature=..."
      end

      fields = layers.to_h { |key, value| [ "layers[#{key}]", value.respond_to?(:read) ? file_part(value) : value.to_s ] }

      Record.wrap(post(url.to_s, form: fields))
    end
  end
end
