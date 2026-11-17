$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "snapsbrew"
require "minitest/autorun"

# Talks to a real Snapsbrew instance. The tests read only, except for one
# preview, which costs no credit.
#
#   SNAPSBREW_TEST_URL=https://snaps.example.com SNAPSBREW_TEST_TOKEN=... bin/rake test:integration
class Snapsbrew::LiveTest < Minitest::Test
  def setup
    skip "Set SNAPSBREW_TEST_URL and SNAPSBREW_TEST_TOKEN to run the integration tests" unless ENV["SNAPSBREW_TEST_URL"] && ENV["SNAPSBREW_TEST_TOKEN"]

    @client = Snapsbrew::Client.new(url: ENV["SNAPSBREW_TEST_URL"], token: ENV["SNAPSBREW_TEST_TOKEN"])
  end

  def test_account
    account = @client.account

    assert_kind_of String, account.email
  end

  def test_list_templates
    page = @client.templates.list

    assert_kind_of Array, page.records
    page.each { |template| assert_kind_of String, template.uuid }
  end

  def test_preview_the_first_template
    template = @client.templates.list.first
    skip "The account has no templates" unless template

    html = @client.snaps.preview(template: template.uuid)

    assert_match(/<html/i, html)
  end
end
