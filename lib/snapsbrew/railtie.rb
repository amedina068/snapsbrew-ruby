require "snapsbrew/helper"

module Snapsbrew
  # Reads Rails.application.credentials.snapsbrew and adds the view helpers.
  #
  #   # bin/rails credentials:edit
  #   snapsbrew:
  #     url: https://snaps.example.com
  #     token: ...
  #     signing_key: ...
  #     webhook_secret: whsec_...
  #
  # An initializer that calls Snapsbrew.configure runs later and wins.
  class Railtie < Rails::Railtie
    initializer "snapsbrew.credentials", before: :load_config_initializers do |app|
      if (credentials = app.credentials.snapsbrew)
        Snapsbrew.config.merge!(credentials)
        Snapsbrew.reset!
      end
    end

    initializer "snapsbrew.helper" do
      ActiveSupport.on_load(:action_view) { include Snapsbrew::Helper }
    end
  end
end
