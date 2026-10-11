require "test_helper"

class FinalMeetingContextTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(name: "Example American Legion Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @other_body = @organization.meeting_bodies.create!(name: "Executive Committee", slug: "pec")
    @type = @organization.meeting_types.create!(name: "Membership Meeting", position: 1, active: true)
    @other_type = @organization.meeting_types.create!(name: "Special Meeting", position: 2, active: true)
    @officer = user("Officer", "manage_agendas", "attest_minutes", "record_minutes_approval")
    @member = user("Member")
    _token, plaintext = AgentAccessToken.issue!(user: @officer, name: "Meeting agent", expires_in: 1.day)
    @headers = { "Authorization" => "Bearer #{plaintext}" }
  end

  %w[absent draft reopened].each do |agenda_state|
    %w[html api].each do |interface|
      test "#{interface} refuses final historical changes with #{agenda_state} agenda and preserves later reads" do
        prepare_minutes(agenda_state:)
        finalize!
        original = graph
        sign_in_as(@officer)

        historical_changes.each do |field, value|
          attributes = { field => value, "lock_version" => @meeting.reload.lock_version }
          if interface == "html"
            patch admin_meeting_path(@meeting), params: { meeting: attributes }
          else
            patch "/api/meetings/#{@meeting.id}", params: attributes, headers: agent_headers, as: :json
          end
          assert_equal original, graph, "#{interface} #{field} must preserve occurrence and official source identity"
          assert_response :unprocessable_entity
          if interface == "html"
            assert_select ".error-summary", text: /locked because its minutes are approved/
          else
            assert_includes response.parsed_body.fetch("error"), "locked because its minutes are approved"
          end
        end

        get "/api/meetings/#{@meeting.id}", headers: agent_headers, as: :json
        assert_response :success
        assert_equal "Recorded membership meeting", response.parsed_body.dig("meeting", "title")
        sign_in_as(@member)
        get meeting_path(@meeting)
        assert_response :success
        assert_select "a[href='#{meeting_minutes_path(@meeting)}']"
        get meeting_minutes_path(@meeting)
        assert_response :success
        assert_includes response.body, "Official minutes"
        assert_includes response.body, "Approved as presented"
        assert_includes response.body, "final, locked record"
        assert_includes response.body, "Official community report"
        assert_not_includes response.body, "Private source cue"
        assert_select "a[href='#{print_meeting_minutes_path(@meeting)}']"
        assert_equal original, graph
      end
    end
  end

  test "model and direct SQL refuse every historical field using current final state" do
    prepare_minutes
    cached = Meeting.includes(:minutes).find(@meeting.id)
    assert_predicate cached.minutes, :draft?
    finalize!
    original = graph
    other_post = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")

    historical_changes.merge("organization_id" => other_post.id).each do |field, value|
      assert_not cached.update(field => value), "cached pre-final minutes cannot unlock #{field}"
      assert_includes cached.errors[:base], Meeting::FINAL_CONTEXT_ERROR
      cached.reload
      error = assert_raises(ActiveRecord::StatementInvalid) do
        Meeting.transaction(requires_new: true) { Meeting.where(id: @meeting.id).update_all(field => value) }
      end
      assert_includes error.message, Meeting::FINAL_CONTEXT_ERROR
      assert_equal original, graph
    end
  end

  test "draft and pending corrections allow legitimate occurrence and website edits until final attestation" do
    prepare_minutes
    sign_in_as(@officer)
    patch admin_meeting_path(@meeting), params: { meeting: { title: "Draft occurrence corrected" } }
    assert_redirected_to admin_meeting_path(@meeting)
    assert_equal "Draft occurrence corrected", @meeting.reload.title
    assert_equal "Recorded membership meeting", @minutes.reload.title, "minutes retain their independent heading snapshot"

    attest!
    @minutes.record_membership_approval_with_confirmation!(confirmation: confirmation("record_membership_approval",
      approving_meeting_id: approving_meeting.id, disposition: "approved_as_corrected", corrections_pending: true,
      factual_note: "Correct the report wording."))
    last_attested = @minutes.member_revision
    patch "/api/meetings/#{@meeting.id}", params: { location_name: "Corrected Hall" }, headers: agent_headers, as: :json
    assert_response :success
    assert_equal "Corrected Hall", @meeting.reload.location_name
    assert_equal last_attested.id, @minutes.reload.member_revision.id
    assert_not_predicate @minutes, :membership_approved?

    attest!
    assert_predicate @minutes.reload, :membership_approved?
    original = graph
    patch "/api/meetings/#{@meeting.id}", params: {
      website_title: "Public meeting notice", website_description: "Contact the Post for information.",
      website_listing: "hide", attendance: "members", calendar_category: "member_meeting", cancelled: false
    }, headers: agent_headers, as: :json
    assert_response :success
    assert_equal "Public meeting notice", @meeting.reload.website_title
    assert_equal "hide", @meeting.website_listing
    assert_equal original.fetch("official"), graph.fetch("official")
    assert_equal original.fetch("historical"), graph.fetch("historical")

    patch "/api/meetings/#{@meeting.id}", params: { title: "Forbidden later correction" }, headers: agent_headers, as: :json
    assert_response :unprocessable_entity
    assert_equal "Draft occurrence corrected", @meeting.reload.title
  end

  private

  def user(label, *capabilities)
    record = User.create!(person: Person.create!(first_name: "Synthetic", last_name: label), email_address: "context-#{label.downcase}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| record.permission_grants.create!(capability:) }
    record
  end

  def prepare_minutes(agenda_state: "absent")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, meeting_type: @type,
      starts_at: 2.weeks.ago, title: "Recorded membership meeting", location_name: "Recorded Hall", location_address: "123 Example Street")
    unless agenda_state == "absent"
      @agenda = DatedAgenda.create_from_template!(meeting: @meeting)
      @agenda.dated_agenda_items.create!(title: "Community report", behavior_type: "report_slot", position: 1, commander_notes: "Private source cue")
      if agenda_state == "reopened"
        @agenda.approve!(@officer)
        @agenda.reopen!(@officer)
      end
    end
    @minutes = MeetingMinutes.create_from_meeting!(meeting: @meeting)
    item = @minutes.items.first || @minutes.sections.first.items.create!(title: "Community report", behavior_type: "report_slot", position: 1)
    item.update!(body: "Official community report")
  end

  def agent_headers
    @headers.merge("Idempotency-Key" => SecureRandom.uuid)
  end

  def historical_changes
    { "title" => "Rewritten heading", "starts_at" => 3.weeks.ago.iso8601, "meeting_body_id" => @other_body.id,
      "meeting_type_id" => @other_type.id, "location_name" => "Rewritten Hall", "location_address" => "456 Changed Street" }
  end

  def confirmation(action, payload = {})
    OfficialActionConfirmation.record_external!(minutes: @minutes, user: @officer, action:, action_payload: payload,
      evidence_note: "Synthetic occurrence safeguard test.")
  end

  def attest!
    @minutes.reload.attest_with_confirmation!(confirmation: confirmation("attest"))
  end

  def approving_meeting
    @approving_meeting ||= create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.week.ago, title: "Later approval meeting")
  end

  def finalize!
    attest!
    @minutes.record_membership_approval_with_confirmation!(confirmation: confirmation("record_membership_approval",
      approving_meeting_id: approving_meeting.id, disposition: "approved_as_presented"))
  end

  def graph
    @minutes.reload
    { "historical" => @meeting.reload.attributes.slice(*%w[organization_id meeting_body_id meeting_type_id starts_at title location_name location_address]),
      "official" => [ @minutes.attributes, @minutes.member_revision&.attributes, @minutes.membership_approval&.attributes,
        @minutes.member_revision&.attestation&.attributes,
        @minutes.revisions.order(:id).map(&:attributes), @minutes.lifecycle_events.order(:id).map(&:attributes),
        @minutes.items.order(:id).map(&:attributes), @agenda&.reload&.attributes ] }
  end
end
