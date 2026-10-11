require "application_system_test_case"
require_relative "../support/minutes_enqueue_support"

class MinutesBackgroundDraftingTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper
  include MinutesEnqueueSupport
  setup do
    organization = Organization.create!(name: "Test American Legion Post", unit_type: "american_legion_post",
      timezone: "America/Chicago", default_location_name: "Legion Hall")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Adjutant"),
      email_address: "background-drafting@example.com", email_verified_at: Time.current)
    @grant = PermissionGrant.create!(user: @user, capability: "manage_minutes")
    body = organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: organization, meeting_body: body, starts_at: 1.day.ago,
      title: "October Membership Meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @transcript = MeetingTranscripts::Create.new(meeting: @meeting, created_by: @user, retention_policy: "delete_after_acceptance",
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
      capture_system_screenshot("minutes-background-disclosure-#{label}")
    end
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "rejected draft and retry show truthful failure before restored enqueue and authority loss" do
    @minutes.sections.first.items.create!(title: "Synthetic service report", behavior_type: "report_slot", position: 1,
      body: "The committee supplied an independently reviewed report.")
    original = saved_minutes_source_graph(@minutes, @transcript)
    visit new_admin_meeting_minutes_draft_run_path(@meeting)
    with_rejected_minutes_enqueue do
      click_button "Send transcript and create draft"
      assert_selector ".ai-draft-failure", text: "The background draft worker could not be started."
    end
    failed = @minutes.draft_runs.recent.first
    assert_rejected_minutes_run(failed, requester: @user, transcript: @transcript)
    assert_equal original, saved_minutes_source_graph(@minutes, @transcript)
    stored_failure = failed.attributes
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 1200)
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      assert_operator find(".ai-draft-failure > p:last-of-type").evaluate_script("parseFloat(getComputedStyle(this).fontSize)"), :>=, 16
      assert_link "Try again"
      assert_link "Continue manually"
      capture_system_screenshot("minutes-enqueue-failure-#{width}")
    end
    click_link "Continue manually"
    assert_selector ".minutes-status-card h2", text: "Draft", exact_text: true
    assert_text "The committee supplied an independently reviewed report."
    assert_equal original, saved_minutes_source_graph(@minutes, @transcript)

    visit admin_jobs_path(filter: "attention")
    with_rejected_minutes_enqueue do
      within ".jobs-run--failed" do
        accept_confirm { click_button "Retry as new run" }
      end
      assert_selector ".jobs-run--failed", count: 2
    end
    rejected = @minutes.draft_runs.recent.first
    assert_rejected_minutes_run(rejected, requester: @user, transcript: @transcript, retry_of: failed)
    assert_equal stored_failure, failed.reload.attributes
    assert_equal original, saved_minutes_source_graph(@minutes, @transcript)
    stored_rejected = rejected.attributes

    assert_enqueued_with(job: MinutesDraftGenerationJob) do
      within find("form[action='#{retry_admin_job_path(failed)}']").ancestor(".jobs-run") do
        accept_confirm { click_button "Retry as new run" }
      end
      assert_selector ".ai-draft-dispatch", text: "Your draft is in line"
    end
    retry_run = @minutes.draft_runs.recent.first
    assert_equal failed.id, retry_run.retry_of_id
    assert_equal "pending", retry_run.status
    assert_equal stored_failure, failed.reload.attributes
    assert_equal stored_rejected, rejected.reload.attributes
    assert_equal original, saved_minutes_source_graph(@minutes, @transcript)
    [ 1400, 390 ].each do |width|
      page.current_window.resize_to(width, 1200)
      assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
      capture_system_screenshot("minutes-enqueue-recovered-#{width}")
    end

    @grant.destroy!
    click_button "Check status now"
    assert_selector ".ai-draft-dispatch-message", text: "The status check was interrupted."
    assert_equal original, saved_minutes_source_graph(@minutes, @transcript)
    visit admin_meeting_minutes_draft_run_path(@meeting, retry_run)
    assert_current_path root_path
    visit profile_path
    assert_text @user.person.full_name
    assert_equal original, saved_minutes_source_graph(@minutes, @transcript)
  ensure
    page.current_window.resize_to(1400, 1400)
  end
end
