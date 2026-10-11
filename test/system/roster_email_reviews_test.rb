require "application_system_test_case"

class RosterEmailReviewsSystemTest < ApplicationSystemTestCase
  test "invalid review preserves identity and ordinary email choices survive later navigation" do
    Organization.create!(name: "Synthetic email review Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    other_user = User.create!(person: Person.create!(first_name: "Other", last_name: "Member"), email_address: "other-member@example.test")
    other_user.permission_grants.create!(capability: "manage_agendas")
    choices = [
      [ "update_login", "updated_login", "Use roster email for login", 1400 ],
      [ "keep_current", "keep_current", "Keep my current login email", 390 ],
      [ "remind_later", "remind_later", "Remind me later", 390 ]
    ]
    freeze_time
    choices.each do |decision, stored_decision, button, width|
      person = Person.create!(first_name: "Review", last_name: decision, member_number: "M108-#{decision}",
        roster_member_status: "Active", roster_email_address: "roster-#{decision}@example.test", roster_imported_at: Time.current)
      user = User.create!(person: person, email_address: "login-#{decision}@example.test", email_verified_at: Time.current)
      user.permission_grants.create!(capability: "view_internal_records")
      page.current_window.resize_to(width, width == 1400 ? 1400 : 844)
      system_sign_in(user)
      original_person = person.attributes
      original_user = user.attributes
      original_sessions = user.sessions.order(:id).map(&:attributes)
      original_grants = PermissionGrant.order(:id).map(&:attributes)

      travel 5.minutes
      assert_selector "h2", text: "Review your login email"
      form = find_button("Use roster email for login").find(:xpath, "..")
      page.execute_script("arguments[0].action = arguments[1]", form, roster_email_review_path(decision: "nope"))
      click_button "Use roster email for login"
      assert_text "Choose how to handle the roster email difference."
      assert_equal original_user, user.reload.attributes
      assert_equal original_person, person.reload.attributes
      assert_equal original_sessions, user.sessions.order(:id).map(&:attributes)
      assert_equal original_grants, PermissionGrant.order(:id).map(&:attributes)
      assert_selector "h2", text: "Review your login email"
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      capture_system_screenshot("email-review-refusal-#{decision}-#{width}")

      click_button button
      assert_no_selector "h2", text: "Review your login email"
      assert_equal person.roster_email_address, user.reload.roster_email_reviewed_address
      assert_equal stored_decision, user.roster_email_review_decision
      assert_equal Time.current, user.roster_email_reviewed_at
      expected_email = decision == "update_login" ? person.roster_email_address : original_user.fetch("email_address")
      assert_equal expected_email, user.email_address
      assert_equal original_person, person.reload.attributes
      assert_equal original_sessions, user.sessions.order(:id).map(&:attributes)
      assert_equal original_grants, PermissionGrant.order(:id).map(&:attributes)
      visit profile_path
      assert_selector "h1", text: "Your profile"
      assert_selector ".profile-lead .page-sub", text: person.full_name
      assert_no_selector ".profile-lead .page-sub", text: "Other Member"

      next unless decision == "remind_later"

      visit root_path
      assert_no_selector "h2", text: "Review your login email"
      click_button "Menu"
      click_button "Sign out"
      assert_current_path new_session_path
      visit profile_path
      assert_current_path new_session_path
      assert_no_selector "h1", text: "Your profile"
      system_sign_in(user)
      assert_selector "h2", text: "Review your login email"
      assert_equal original_person, person.reload.attributes
      assert_equal "remind_later", user.reload.roster_email_review_decision
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
