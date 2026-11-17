$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "snapsbrew"
require "tmpdir"
require "fileutils"

# A minimal Rails app. Its credentials hold the snapsbrew settings, and an
# initializer changes one of them.
DUMMY_ROOT = Dir.mktmpdir("snapsbrew-rails")
at_exit { FileUtils.rm_rf(DUMMY_ROOT) }
FileUtils.mkdir_p("#{DUMMY_ROOT}/config/initializers")
File.write("#{DUMMY_ROOT}/config/initializers/snapsbrew.rb", "Snapsbrew.configure { |config| config.timeout = 5 }\n")

File.write("#{DUMMY_ROOT}/config/test.key", ActiveSupport::EncryptedConfiguration.generate_key)
ActiveSupport::EncryptedConfiguration.new(
  config_path: "#{DUMMY_ROOT}/config/test.yml.enc", key_path: "#{DUMMY_ROOT}/config/test.key",
  env_key: "SNAPSBREW_TEST_MASTER_KEY", raise_if_missing_key: true
).write(<<~YAML)
  snapsbrew:
    url: https://snaps.test
    token: credentials-token
    signing_key: credentials-key
YAML

class Dummy < Rails::Application
  config.root = DUMMY_ROOT
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = "0" * 64
  config.hosts.clear
  config.credentials.content_path = Pathname("#{DUMMY_ROOT}/config/test.yml.enc")
  config.credentials.key_path = Pathname("#{DUMMY_ROOT}/config/test.key")

  routes.append do
    get "/post" => "posts#show"
  end
end

class PostsController < ActionController::Base
  def show
    render inline: <<~ERB
      <%= snapsbrew_og_image_tag template: "t1", title: "Dark Avengers" %>
      <%= snapsbrew_image_tag template: "t1", alt: "Dark Avengers", title: "Dark Avengers", html: { class: "cover" } %>
    ERB
  end
end

Dummy.initialize!

require "minitest/autorun"
require "rails/test_help"
