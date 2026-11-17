require "test_helper"

class Snapsbrew::AccountTest < Snapsbrew::TestCase
  def test_account
    stub_api(:get, "/v1/auth").to_return(json(data: { email: "dev@example.com", name: "Ada Lovelace", company: "Analytical Engines" }))

    account = client.account

    assert_equal "dev@example.com", account.email
    assert_equal "Analytical Engines", account[:company]
  end
end
