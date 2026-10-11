require "test_helper"

class RosterEmailReviewsControllerTest < ActionDispatch::IntegrationTest
  test "update_login changes login email to roster email" do
    user = member_with_roster_mismatch
    sign_in_as(user)
    original_identity = roster_identity_state(reviewed_user: user)

    freeze_time do
      patch roster_email_review_path, params: { decision: "update_login" }
      assert_equal "roster@example.com", user.reload.roster_email_reviewed_address
      assert_equal "updated_login", user.roster_email_review_decision
      assert_equal Time.current, user.roster_email_reviewed_at
      assert_equal original_identity, roster_identity_state(reviewed_user: user)
    end

    assert_redirected_to root_path
    assert_equal "roster@example.com", user.reload.email_address
    assert_not user.needs_roster_email_review?
    get profile_path
    assert_response :success
    assert_select ".app-menu-panel", text: /Jane Doe/
  end

  test "keep_current keeps login email and stops prompting" do
    user = member_with_roster_mismatch
    sign_in_as(user)
    original_identity = roster_identity_state(reviewed_user: user)

    freeze_time do
      patch roster_email_review_path, params: { decision: "keep_current" }
      assert_equal "roster@example.com", user.reload.roster_email_reviewed_address
      assert_equal "keep_current", user.roster_email_review_decision
      assert_equal Time.current, user.roster_email_reviewed_at
      assert_equal original_identity, roster_identity_state(reviewed_user: user)
    end

    assert_redirected_to root_path
    assert_equal "login@example.com", user.reload.email_address
    assert_not user.needs_roster_email_review?
    get profile_path
    assert_response :success
    assert_select ".app-menu-panel", text: /Jane Doe/
  end

  test "remind_later keeps prompting" do
    user = member_with_roster_mismatch
    sign_in_as(user)
    original_identity = roster_identity_state(reviewed_user: user)

    freeze_time do
      patch roster_email_review_path, params: { decision: "remind_later" }
      assert_equal "roster@example.com", user.reload.roster_email_reviewed_address
      assert_equal "remind_later", user.roster_email_review_decision
      assert_equal Time.current, user.roster_email_reviewed_at
      assert_equal original_identity, roster_identity_state(reviewed_user: user)
    end

    assert_redirected_to root_path
    assert user.reload.needs_roster_email_review?
    get profile_path
    assert_response :success
    assert_select ".app-menu-panel", text: /Jane Doe/
  end

  test "invalid decision redirects with alert" do
    user = member_with_roster_mismatch
    sign_in_as(user)
    original = roster_identity_state

    patch roster_email_review_path, params: { decision: "nope" }

    assert_equal original, roster_identity_state
    assert_redirected_to root_path
    assert_equal "Choose how to handle the roster email difference.", flash[:alert]
    get profile_path
    assert_response :success
    assert_select ".app-menu-panel", text: /Jane Doe/
  end

  test "unauthenticated update redirects to sign in" do
    user = member_with_roster_mismatch
    original = roster_identity_state

    patch roster_email_review_path, params: { decision: "update_login" }

    assert_equal original, roster_identity_state
    assert_redirected_to new_session_path
    get profile_path
    assert_redirected_to new_session_path
    assert_not_includes response.body, "roster@example.com"

    sign_in_as(user)
    get profile_path
    assert_response :success
    assert_select ".app-menu-panel", text: /Jane Doe/
  end

  private

  def roster_identity_state(reviewed_user: nil)
    users = User.order(:id).map do |user|
      attributes = user.attributes
      if user.id == reviewed_user&.id
        attributes.except("email_address", "roster_email_reviewed_address", "roster_email_review_decision", "roster_email_reviewed_at", "updated_at")
      else
        attributes
      end
    end
    [ Person.order(:id).map(&:attributes), users,
      PermissionGrant.order(:id).map(&:attributes), Session.order(:id).map(&:attributes) ]
  end

  def member_with_roster_mismatch
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    other = Person.create!(first_name: "Other", last_name: "Member", roster_email_address: "other-roster@example.test")
    other_user = User.create!(person: other, email_address: "other-login@example.test")
    other_user.permission_grants.create!(capability: "manage_agendas")
    person = Person.create!(first_name: "Jane", last_name: "Doe", member_number: "M108", roster_member_status: "Active",
      roster_email_address: "roster@example.com", roster_imported_at: Time.current)
    user = User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)
    user.permission_grants.create!(capability: "view_internal_records")
    user
  end
end
