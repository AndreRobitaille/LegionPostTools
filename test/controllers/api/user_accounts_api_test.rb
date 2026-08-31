require "test_helper"

class ApiUserAccountsApiTest < ActionDispatch::IntegrationTest
  setup do
    Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @admin = create_user("Admin", "manage_settings")
    @member = Person.create!(
      first_name: "Roster",
      last_name: "Member",
      member_number: "123456789",
      roster_email_address: "roster@example.com",
      roster_member_status: "Active",
      roster_imported_at: Time.current
    )
    sign_in_as(@admin)
  end

  test "administrator agent can inspect enable disable and restore roster control" do
    get "/api/people/#{@member.id}/account", as: :json
    assert_response :success
    assert_nil response.parsed_body.dig("user_account", "account")

    post "/api/people/#{@member.id}/account", params: { email_address: "login@example.com" }, as: :json
    assert_response :created
    user = @member.reload.user
    assert_equal "login@example.com", user.email_address
    assert_nil user.disabled_at
    assert_not user.login_access_override?
    assert_equal "enabled_by_roster_status", response.parsed_body["access_result"]

    delete "/api/people/#{@member.id}/account", as: :json
    assert_response :success
    assert user.reload.disabled_at.present?
    assert user.login_access_override?
    assert_equal "manual", user.disabled_reason

    patch "/api/people/#{@member.id}/account/roster_control", as: :json
    assert_response :success
    assert_nil user.reload.disabled_at
    assert_not user.login_access_override?
    assert_equal "enabled_by_roster_status", response.parsed_body["access_result"]
  end

  test "API preserves the final enabled administrator" do
    delete "/api/people/#{@admin.person_id}/account", as: :json

    assert_response :unprocessable_entity
    assert_match(/At least one enabled administrator/, response.parsed_body["error"])
    assert_nil @admin.reload.disabled_at
  end

  test "plain member cannot operate account controls" do
    plain = create_user("Plain")
    sign_in_as(plain)

    get "/api/people/#{@member.id}/account", as: :json

    assert_response :forbidden
  end

  private

  def create_user(label, capability = nil)
    person = Person.create!(first_name: "Test", last_name: "#{label}-#{SecureRandom.hex(3)}")
    user = User.create!(person: person, email_address: "#{label.downcase}-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    user.permission_grants.create!(capability: capability) if capability
    user
  end
end
