require "test_helper"

class Snapsbrew::ConfigurationTest < Snapsbrew::TestCase
  def setup
    super
    @config = Snapsbrew.instance_variable_get(:@config)
    Snapsbrew.instance_variable_set(:@config, nil)
    Snapsbrew.reset!
  end

  def teardown
    Snapsbrew.instance_variable_set(:@config, @config)
    Snapsbrew.reset!
    %w[ SNAPSBREW_URL SNAPSBREW_TOKEN SNAPSBREW_SIGNING_KEY ].each { |name| ENV.delete(name) }
  end

  def test_configure_builds_the_default_client
    Snapsbrew.configure do |config|
      config.url = URL
      config.token = TOKEN
      config.timeout = 5
      config.max_retries = 0
    end

    assert_equal URL, Snapsbrew.client.url
    assert_equal 5, Snapsbrew.client.timeout
    assert_equal 0, Snapsbrew.client.max_retries
  end

  def test_configure_replaces_the_default_client
    Snapsbrew.configure { |config| config.url = URL }
    first = Snapsbrew.client
    Snapsbrew.configure { |config| config.url = "https://other.test" }

    refute_same first, Snapsbrew.client
    assert_equal "https://other.test", Snapsbrew.client.url
  end

  def test_environment_variables_are_the_fallback
    ENV["SNAPSBREW_URL"] = "https://env.test"
    ENV["SNAPSBREW_TOKEN"] = "env-token"
    ENV["SNAPSBREW_SIGNING_KEY"] = "env-key"

    assert_equal({ url: "https://env.test", token: "env-token", signing_key: "env-key", timeout: 60, max_retries: 2 }, Snapsbrew.config.to_h)
  end

  def test_merge_copies_known_keys_only
    Snapsbrew.config.merge!(url: URL, token: TOKEN, unknown: "x")

    assert_equal URL, Snapsbrew.config.url
    assert_equal TOKEN, Snapsbrew.config.token
  end

  def test_the_module_delegates_to_the_default_client
    Snapsbrew.configure do |config|
      config.url = URL
      config.token = TOKEN
      config.signing_key = "key"
    end
    stub_api(:get, "/v1/auth").to_return(json(data: { name: "Ada Lovelace" }))

    assert_equal "Ada Lovelace", Snapsbrew.account.name
    assert_instance_of Snapsbrew::Snaps, Snapsbrew.snaps
    assert Snapsbrew.signed_url(template: "t1", title: "Hello").start_with?("#{URL}/signed-url/image.jpg?")
  end

  def test_inspect_hides_the_token
    Snapsbrew.config.token = "secret-token"

    refute_includes Snapsbrew.config.inspect, "secret-token"
  end
end
