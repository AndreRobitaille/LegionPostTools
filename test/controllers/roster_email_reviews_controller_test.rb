require "test_helper"

class RosterEmailReviewsControllerTest < ActionDispatch::IntegrationTest
  test "update_login changes login email to roster email" do
    user = member_with_roster_mismatch
    sign_in_as(user)

    patch roster_email_review_path, params: { decision: "update_login" }

    assert_redirected_to root_path
    assert_equal "roster@example.com", user.reload.email_address
    assert_not user.needs_roster_email_review?
  end

  test "keep_current keeps login email and stops prompting" do
    user = member_with_roster_mismatch
    sign_in_as(user)

    patch roster_email_review_path, params: { decision: "keep_current" }

    assert_redirected_to root_path
    assert_equal "login@example.com", user.reload.email_address
    assert_not user.needs_roster_email_review?
  end

  test "remind_later keeps prompting" do
    user = member_with_roster_mismatch
    sign_in_as(user)

    patch roster_email_review_path, params: { decision: "remind_later" }

    assert_redirected_to root_path
    assert user.reload.needs_roster_email_review?
  end

  test "invalid decision redirects with alert" do
    user = member_with_roster_mismatch
    sign_in_as(user)

    patch roster_email_review_path, params: { decision: "nope" }

    assert_redirected_to root_path
    assert_equal "Choose how to handle the roster email difference.", flash[:alert]
  end

  test "unauthenticated update redirects to sign in" do
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    Person.create!(first_name: "Jane", last_name: "Doe")
    Installation.singleton.update!(setup_completed_at: Time.current)

    patch roster_email_review_path, params: { decision: "update_login" }

    assert_redirected_to new_session_path
  end

  private

  def member_with_roster_mismatch
    Organization.create!(name: "Robert E. Burns Post 165", unit_type: "american_legion_post", timezone: "America/Chicago")
    person = Person.create!(first_name: "Jane", last_name: "Doe", roster_email_address: "roster@example.com")
    User.create!(person: person, email_address: "login@example.com", email_verified_at: Time.current)
  end
end
