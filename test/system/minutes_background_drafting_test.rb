require "application_system_test_case"

class MinutesBackgroundDraftingTest < ApplicationSystemTestCase
  setup do
    organization = Organization.create!(name: "Test American Legion Post", unit_type: "american_legion_post",
      timezone: "America/Chicago", default_location_name: "Legion Hall")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Adjutant"),
      email_address: "background-drafting@example.com", email_verified_at: Time.current)
    PermissionGrant.create!(user: @user, capability: "manage_minutes")
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: organization, meeting_body: body, starts_at: 1.day.ago,
      title: "October Membership Meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    MeetingTranscripts::Create.new(meeting: @meeting, created_by: @user, retention_policy: "delete_after_acceptance",
      pasted_text: "The Commander called the meeting to order.").call
    system_sign_in(@user)
  end

  test "the start page discloses temporary response storage and stays readable at narrow widths" do
    visit new_admin_meeting_minutes_draft_run_path(@meeting)

    assert_selector ".ai-provider-note", text: "OpenAI temporarily stores the response so the app can check progress."
    assert_selector ".ai-draft-source-ticket", text: MinutesDraftProviders::Openai::MODEL
    assert_no_text "GPT-5.6 Sol"
    [ [ 1400, 1400, "desktop" ], [ 390, 1800, "mobile" ] ].each do |width, height, label|
      page.current_window.resize_to(width, height)
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      assert_operator page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.ai-provider-note p')).fontSize)"), :>=, 16
      assert_operator page.evaluate_script("parseFloat(getComputedStyle(document.querySelector('.ai-draft-source-ticket dt')).fontSize)"), :>=, 13
      assert_button "Send transcript and create draft"
      assert_link "Continue manually"
      page.save_screenshot("/tmp/minutes-background-disclosure-#{label}.png")
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
