require "application_system_test_case"

class MinutesEndeavorConfirmationTest < ApplicationSystemTestCase
  FakeProvider = Data.define(:result) do
    def draft(**) = result
  end

  setup do
    @organization = Organization.create!(name: "Test American Legion Post", unit_type: "american_legion_post",
      timezone: "America/Chicago", default_location_name: "Legion Hall")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @user = User.create!(person: Person.create!(first_name: "Jane", last_name: "Adjutant"),
      email_address: "jane@example.com", email_verified_at: Time.current)
    %w[manage_minutes manage_agendas].each { |capability| PermissionGrant.create!(user: @user, capability: capability) }
    body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: body, starts_at: 1.day.ago, title: "September Membership Meeting")
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @item = @minutes.sections.first.items.create!(title: "Community breakfast proposal", behavior_type: "business_item",
      position: 1, agenda_body: "Discuss whether the Post should organize a breakfast.",
      body: "The Post agreed to organize a breakfast and recruit volunteers.")
    @existing = @organization.endeavors.create!(title: "Veteran outreach", summary: "Coordinate volunteer outreach.",
      created_by: @user, importance: "standard", status: "active")
    system_sign_in(@user)
  end

  test "manual creation stays inside minutes and is readable at desktop and narrow widths" do
    visit admin_meeting_minutes_path(@meeting)
    within ".minutes-item-card", text: @item.title do
      click_link "Create Endeavor from this discussion"
    end
    assert_field "Endeavor title", with: @item.title
    assert_field "Description", with: @item.body.to_plain_text
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    capture_system_screenshot("minutes-endeavor-manual-desktop")
    page.current_window.resize_to(390, 1200)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    capture_system_screenshot("minutes-endeavor-manual-mobile")
    find("input[name='confirmation[title]']").click
    find("input[name='confirmation[title]']").send_keys(:tab)
    assert_equal "confirmation_body", page.evaluate_script("document.activeElement.id")
    fill_in "Endeavor title", with: "2027 Community Breakfast"
    fill_in "Description", with: "Plan the breakfast and coordinate volunteers."
    click_button "Create and link"
    assert_current_path admin_meeting_minutes_path(@meeting)
    assert_text "Endeavor linked: 2027 Community Breakfast."
    assert_equal @user, @item.reload.endeavor.created_by
    assert_equal "Discuss whether the Post should organize a breakfast.", @item.agenda_body.to_plain_text
    assert_equal "The Post agreed to organize a breakfast and recruit volunteers.", @item.body.to_plain_text
    assert_no_link "Create Endeavor from this discussion"
    assert_link "Change Endeavor link"
    page.current_window.resize_to(390, 2400)
    capture_system_screenshot("minutes-endeavor-workspace-mobile")
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "AI proposal opens the shared form with source evidence and records edited human confirmation" do
    @item.update!(title: "Community breakfast and volunteer recruitment for the coming year")
    run = generate_proposals
    proposal = run.suggestions.sole
    visit admin_meeting_minutes_draft_run_path(@meeting, run)
    assert_text /Suggested new Endeavor/i
    assert_text "Continuing planning and volunteer recruitment."
    assert_link "Review and create"
    assert_no_button "Use suggestion"
    capture_system_screenshot("minutes-endeavor-ai-desktop")
    page.current_window.resize_to(390, 1200)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    capture_system_screenshot("minutes-endeavor-ai-review-mobile")
    click_link "Edit proposal"
    assert_selector ".minutes-endeavor-evidence", text: /Post agreed to organize a breakfast/
    assert_field "Endeavor title", with: "Community breakfast"
    page.current_window.resize_to(390, 1800)
    assert_not page.evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    capture_system_screenshot("minutes-endeavor-ai-mobile")
    fill_in "Endeavor title", with: "Community Breakfast Program"
    fill_in "Description", with: "Plan recurring breakfasts and volunteer recruitment."
    click_button "Create and link"
    assert_current_path admin_meeting_minutes_path(@meeting)
    assert_equal "edited", proposal.reload.review_state
    assert_equal @user, proposal.reviewed_by
    assert_equal @item.reload.endeavor_id, proposal.applied_record_id
    assert_equal "Community breakfast", proposal.payload["title"]
  ensure
    page.current_window.resize_to(1400, 1400)
  end

  test "officer confirms an existing Endeavor and can dismiss a separate proposal" do
    other = @minutes.sections.first.items.create!(title: "Building repair discussion", behavior_type: "business_item", position: 2)
    run = generate_proposals(existing: true, other_item: other)
    proposal = run.suggestions.find_by!(minutes_item: @item)
    dismissed = run.suggestions.find_by!(minutes_item: other)
    visit admin_meeting_minutes_draft_run_path(@meeting, run)
    within "#review_minutes_draft_suggestion_#{proposal.id}" do
      assert_text /Suggested Endeavor link/i
      assert_no_link "Review and create"
      click_link "Link existing"
    end
    assert_select "Existing Endeavor", selected: @existing.title
    assert_no_difference "Endeavor.count" do
      click_button "Link Endeavor"
      assert_current_path admin_meeting_minutes_path(@meeting)
    end
    assert_equal @existing, @item.reload.endeavor
    assert_equal "used", proposal.reload.review_state

    visit admin_meeting_minutes_draft_run_path(@meeting, run)
    within "#review_minutes_draft_suggestion_#{dismissed.id}" do
      click_button "Dismiss"
      assert_text /Discarded/i
    end
    assert_nil other.reload.endeavor_id
    assert_equal @user, dismissed.reload.reviewed_by
  end

  private

  def generate_proposals(existing: false, other_item: nil)
    MeetingTranscripts::Create.new(meeting: @meeting, created_by: @user, retention_policy: "delete_after_acceptance",
      pasted_text: "The Post agreed to organize a breakfast and recruit volunteers.\nThe members discussed continuing building repair work.").call
    rows = [ proposal_attributes(@item, existing ? @existing.id : nil) ]
    rows << proposal_attributes(other_item, nil) if other_item
    result = MinutesDraftProviders::Result.new(data: { "suggestions" => rows }, provider_response_id: "synthetic",
      provider_request_id: "synthetic", model: "synthetic-offline", input_tokens: 0, output_tokens: 0, reasoning_tokens: 0, total_tokens: 0)
    MinutesDrafting::Generate.call(minutes: @minutes, requester: @user, provider: FakeProvider.new(result))
  end

  def proposal_attributes(item, endeavor_id)
    {
      "kind" => "endeavor_proposal", "target_id" => item.id, "source_agenda_item_id" => nil,
      "endeavor_id" => endeavor_id, "title" => "Community breakfast", "body" => "Plan a breakfast and recruit volunteers.",
      "endeavor_reason" => "Continuing planning and volunteer recruitment.", "source_start_line" => 1,
      "source_end_line" => 1, "confidence" => "high", "missing_facts" => []
    }
  end
end
