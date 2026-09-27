require "test_helper"

class WebsiteAccessTokenTest < ActiveSupport::TestCase
  setup do
    @organization = Organization.create!(name: "Synthetic Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    @admin = User.create!(person: Person.create!(first_name: "Token", last_name: "Creator"), email_address: "creator@example.test")
    @token, @secret = WebsiteAccessToken.issue!(organization: @organization, actor: @admin, name: "  Website  ")
  end

  test "only a digest is stored and malformed or wrong secrets do not authenticate" do
    assert_match(/\Alptw_[0-9a-f]{24}_[0-9a-f]{64}\z/, @secret)
    assert_equal "Website", @token.name
    assert_not_includes @token.attributes.values, @secret
    assert_not_includes @token.attributes.values, @secret.split("_").last
    [ nil, "", @secret + "extra", @secret.sub("lptw", "lpt"), "lptw_#{@token.public_id}_#{'0' * 64}" ].each do |invalid|
      assert_nil WebsiteAccessToken.authenticate(invalid)
    end
    assert_nil @token.reload.last_used_at
    assert_equal @token, WebsiteAccessToken.authenticate(@secret)
    used_at = @token.reload.last_used_at
    travel 1.minute do
      WebsiteAccessToken.authenticate(@secret)
      assert_equal used_at, @token.reload.last_used_at
    end
    travel 16.minutes do
      WebsiteAccessToken.authenticate(@secret)
      assert_operator @token.reload.last_used_at, :>, used_at
    end
  end

  test "website authority is independent of the creator account and roles" do
    @admin.permission_grants.create!(capability: "manage_settings")
    @admin.permission_grants.destroy_all
    @admin.update!(disabled_at: Time.current)
    assert_equal @token, WebsiteAccessToken.authenticate(@secret)
    assert_equal @organization, @token.organization
    assert_nil AgentAccessToken.authenticate(@secret)
    travel 2.years do
      assert_equal @token, WebsiteAccessToken.authenticate(@secret)
    end
  end

  test "revocation retains the first actor and timestamp and supports overlapping replacement" do
    replacement, secret = WebsiteAccessToken.issue!(organization: @organization, actor: @admin, name: "Replacement")
    @token.revoke!(@admin)
    revoked_at = @token.revoked_at
    travel 1.minute do
      @token.revoke!(@admin)
    end
    assert_equal revoked_at, @token.reload.revoked_at
    assert_equal @admin, @token.revoked_by
    assert_nil WebsiteAccessToken.authenticate(@secret)
    assert_equal replacement, WebsiteAccessToken.authenticate(secret)
    assert WebsiteAccessToken.exists?(@token.id)
  end
end
