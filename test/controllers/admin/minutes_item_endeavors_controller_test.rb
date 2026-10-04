require "test_helper"

class Admin::MinutesItemEndeavorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Test Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago)
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @item = @minutes.sections.first.items.create!(title: "Community breakfast", behavior_type: "business_item", position: 1,
      agenda_body: "Discuss interest in a breakfast.", body: "The Post agreed to organize a community breakfast.")
    @manager = user_with_capabilities("manage_minutes", "manage_agendas")
    @existing = @organization.endeavors.create!(title: "Flag outreach", created_by: @manager, importance: "standard", status: "active")
  end

  test "manual form starts with the discussion and creation returns to minutes without rewriting it" do
    sign_in_as(@manager)
    get new_admin_meeting_minutes_item_endeavor_path(@meeting, @item)
    assert_response :success
    assert_select "input[name='confirmation[title]'][value='Community breakfast']"
    assert_select "textarea[name='confirmation[body]']", text: /Post agreed to organize/
    assert_select ".minutes-endeavor-existing", text: /Flag outreach/

    assert_no_changes -> { [ @item.reload.title, @item.body.to_plain_text, @item.agenda_body.to_plain_text, @item.position ] } do
      assert_difference "Endeavor.count", 1 do
        post_confirmation(title: "Community breakfast", body: "Plan the breakfast and recruit volunteers.")
      end
    end
    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_equal @manager, @item.reload.endeavor.created_by
    assert_equal "Plan the breakfast and recruit volunteers.", @item.endeavor.summary
    assert_empty @item.outcomes
  end

  test "minutes-only manager may link but cannot create and the workspace reflects those grants" do
    sign_in_as(user_with_capabilities("manage_minutes"))
    get admin_meeting_minutes_path(@meeting)
    assert_select "a", text: "Create Endeavor from this discussion", count: 0
    assert_select "a", text: "Link existing Endeavor"
    get new_admin_meeting_minutes_item_endeavor_path(@meeting, @item)
    assert_redirected_to root_path
    assert_no_difference "Endeavor.count" do
      post_confirmation(title: "Unauthorized")
    end
    assert_redirected_to root_path

    get new_admin_meeting_minutes_item_endeavor_path(@meeting, @item, mode: "link")
    assert_response :success
    post_confirmation(endeavor_action: "link", endeavor_id: @existing.id)
    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_equal @existing, @item.reload.endeavor
  end

  test "sign-in and minutes authority are required for form and submission" do
    get new_admin_meeting_minutes_item_endeavor_path(@meeting, @item)
    assert_redirected_to new_session_path
    assert_no_difference "Endeavor.count" do
      post_confirmation(title: "Restricted")
    end
    assert_redirected_to new_session_path
    sign_in_as(user_with_capabilities("manage_agendas"))
    get new_admin_meeting_minutes_item_endeavor_path(@meeting, @item)
    assert_redirected_to root_path
    assert_no_difference "Endeavor.count" do
      post_confirmation(title: "Restricted")
    end
    assert_redirected_to root_path
  end

  test "validation retains text and creates no partial record or link" do
    sign_in_as(@manager)
    assert_no_difference "Endeavor.count" do
      post_confirmation(title: "", body: "Keep this description.")
    end
    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Title can't be blank/
    assert_select "textarea[name='confirmation[body]']", text: "Keep this description."
    assert_nil @item.reload.endeavor_id
  end

  test "blank existing selection is a recoverable validation error" do
    sign_in_as(@manager)
    post_confirmation(endeavor_action: "link", endeavor_id: "")
    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /Choose an existing Endeavor/
    assert_select "select[name='confirmation[endeavor_id]']"
    assert_nil @item.reload.endeavor_id
  end

  test "duplicate normalized title directs the officer to reuse an Endeavor" do
    sign_in_as(@manager)
    assert_no_difference "Endeavor.count" do
      post_confirmation(title: "  FLAG   outreach  ", body: "Another description")
    end
    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /already exists.*Link existing/
    assert_nil @item.reload.endeavor_id
  end

  test "stale and double submission do not create extra Endeavors" do
    sign_in_as(@manager)
    version = @item.lock_version
    post_confirmation(title: "Community breakfast", lock_version: version)
    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_no_difference "Endeavor.count" do
      post_confirmation(title: "Accidental second Endeavor", lock_version: version)
    end
    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /changed/
    assert_equal "Community breakfast", @item.reload.endeavor.title
  end

  test "parent draft state is rechecked inside the confirmation service" do
    [ "attested", "membership_approved" ].each do |status|
      @minutes.update_columns(status: status)
      assert_no_difference "Endeavor.count" do
        assert_raises(ActiveRecord::RecordInvalid) do
          MinutesEndeavors::Confirm.call(item: @item, reviewer: @manager, attributes: confirmation_values(title: "Blocked"))
        end
      end
    end
    assert_nil @item.reload.endeavor_id
  end

  test "locked minutes hide actions and reject direct creation and linking" do
    sign_in_as(@manager)
    @minutes.update_columns(status: "attested")
    get admin_meeting_minutes_path(@meeting)
    assert_select ".minutes-endeavor-actions", count: 0
    assert_no_difference "Endeavor.count" do
      post_confirmation(title: "Blocked")
    end
    assert_redirected_to admin_meeting_minutes_path(@meeting)
    post_confirmation(endeavor_action: "link", endeavor_id: @existing.id)
    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_nil @item.reload.endeavor_id
  end

  test "cross-meeting items and cross-organization Endeavors are rejected" do
    sign_in_as(@manager)
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    foreign = other.endeavors.create!(title: "Other work", created_by: @manager, importance: "standard", status: "active")
    post_confirmation(endeavor_action: "link", endeavor_id: foreign.id)
    assert_response :not_found
    assert_nil @item.reload.endeavor_id
    other_meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 2.days.ago)
    get new_admin_meeting_minutes_item_endeavor_path(other_meeting, @item)
    assert_response :not_found
  end

  test "AI confirmation records the human and edited result without replacing its proposed payload" do
    sign_in_as(@manager)
    proposal = create_proposal
    original = proposal.payload.deep_dup
    get new_admin_meeting_minutes_item_endeavor_path(@meeting, @item, suggestion_id: proposal.id)
    assert_response :success
    assert_select ".minutes-endeavor-evidence", text: /continuing planning.*Post agreed/m
    post_confirmation(title: "Monthly community breakfast", body: "Organize the recurring breakfast.", suggestion_id: proposal.id)
    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_equal "edited", proposal.reload.review_state
    assert_equal @manager, proposal.reviewed_by
    assert_not_nil proposal.reviewed_at
    assert_equal "Endeavor", proposal.applied_record_type
    assert_equal @item.reload.endeavor_id, proposal.applied_record_id
    assert_equal original, proposal.payload

    assert_no_difference "Endeavor.count" do
      post_confirmation(title: "Another", suggestion_id: proposal.id)
    end
    assert_response :not_found
  end

  test "another item cannot consume this proposal and a newly confirmed link cannot be overwritten" do
    sign_in_as(@manager)
    proposal = create_proposal
    second = @minutes.sections.first.items.create!(title: "Other discussion", behavior_type: "business_item", position: 2)
    get new_admin_meeting_minutes_item_endeavor_path(@meeting, second, suggestion_id: proposal.id)
    assert_response :not_found
    @item.update!(endeavor: @existing)
    assert_no_difference "Endeavor.count" do
      post_confirmation(title: "New work", suggestion_id: proposal.id)
    end
    assert_response :unprocessable_entity
    assert_equal @existing, @item.reload.endeavor
    assert proposal.reload.unreviewed?
  end

  private

  def user_with_capabilities(*capabilities)
    person = Person.create!(first_name: "Review", last_name: "Officer")
    user = User.create!(person: person, email_address: "review-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end

  def confirmation_values(**overrides)
    { endeavor_action: "create", lock_version: @item.lock_version }.merge(overrides)
  end

  def post_confirmation(suggestion_id: nil, **overrides)
    post admin_meeting_minutes_item_endeavor_path(@meeting, @item), params: {
      suggestion_id: suggestion_id, confirmation: confirmation_values(**overrides)
    }
  end

  def create_proposal
    MeetingTranscripts::Create.new(meeting: @meeting, created_by: @manager,
      retention_policy: "delete_after_acceptance", pasted_text: "The Post agreed to organize a breakfast and recruit volunteers.").call
    run = MinutesDrafting::Generate.prepare(minutes: @minutes, requester: @manager)
    run.update!(status: "succeeded")
    run.suggestions.create!(kind: "endeavor_proposal", minutes_item: @item,
      payload: { "title" => "Community breakfast", "body" => "Organize a breakfast.", "reason" => "The breakfast needs continuing planning.", "endeavor_id" => nil },
      source_start_line: 1, source_end_line: 1, confidence: "high", missing_facts: [])
  end
end
