require "rails/generators/base"

module Snapsbrew
  module Generators
    # bin/rails generate snapsbrew:install
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Writes config/initializers/snapsbrew.rb"

      def copy_initializer
        template "snapsbrew.rb", "config/initializers/snapsbrew.rb"
      end

      def show_credentials
        say <<~TEXT

          Add the settings of your Snapsbrew instance to the credentials:

            bin/rails credentials:edit

            snapsbrew:
              url: https://snaps.example.com
              token: your-api-token
              signing_key: your-signing-key
              webhook_secret: whsec_your-webhook-secret

        TEXT
      end
    end
  end
end
