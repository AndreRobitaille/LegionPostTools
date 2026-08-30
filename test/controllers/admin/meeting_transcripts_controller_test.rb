require "test_helper"

class Admin::MeetingTranscriptsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = Organization.create!(
      name: "Robert E. Burns Post 165",
      unit_type: "american_legion_post",
      default_location_name: "Legion Hall",
      timezone: "America/Chicago"
    )
    Installation.singleton.update!(setup_completed_at: Time.current)
    @body = @organization.meeting_bodies.create!(name: "Membership", slug: "membership")
    @meeting = create_meeting!(organization: @organization, meeting_body: @body, starts_at: 1.day.ago)
    MeetingMinutes.create_from_meeting!(meeting: @meeting)
    @manager = create_user_with("manage_minutes")
  end

  test "minutes managers can paste a restricted transcript" do
    sign_in_as(@manager)

    get new_admin_meeting_transcript_path(@meeting)
    assert_response :success
    assert_select "textarea[name='meeting_transcript[pasted_text]']"
    assert_select "input[type='file'][accept='.txt,text/plain']"
    assert_select ".transcript-privacy-note", text: /does not send anything to OpenAI/

    assert_difference -> { MeetingTranscript.count }, 1 do
      post admin_meeting_transcript_path(@meeting), params: {
        meeting_transcript: {
          pasted_text: "Commander: Call to order.\r\nAdjutant: Roll call.",
          retention_policy: "delete_after_acceptance"
        }
      }
    end

    assert_redirected_to admin_meeting_minutes_path(@meeting)
    transcript = @meeting.reload.transcript
    assert_equal "Commander: Call to order.\nAdjutant: Roll call.", transcript.content
    assert_equal @manager, transcript.created_by
  end

  test "minutes managers can upload a text transcript" do
    sign_in_as(@manager)
    upload = fixture_file_upload("meeting.txt", "text/plain")

    post admin_meeting_transcript_path(@meeting), params: {
      meeting_transcript: {
        text_upload: upload,
        retention_policy: "retain_restricted"
      }
    }

    assert_equal 1, MeetingTranscript.count, response.body[/<div class="error-summary".*?<\/div>/m]
    assert_redirected_to admin_meeting_minutes_path(@meeting)
    assert_equal "meeting.txt", @meeting.reload.transcript.original_filename
  end

  test "invalid input is rendered without putting transcript text in the error" do
    sign_in_as(@manager)
    post admin_meeting_transcript_path(@meeting), params: {
      meeting_transcript: { pasted_text: "  ", retention_policy: "delete_after_acceptance" }
    }

    assert_response :unprocessable_entity
    assert_select ".error-summary", text: /provide either pasted transcript text or one text file/
    assert_no_match(/Commander said/, response.body)
  end

  test "internal record viewers can read source but cannot add it" do
    transcript = MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @manager,
      pasted_text: "The factual source.",
      retention_policy: "delete_after_acceptance"
    ).call
    viewer = create_user_with("view_internal_records")
    sign_in_as(viewer)

    get admin_meeting_transcript_path(@meeting)
    assert_response :success
    assert_select ".transcript-reader pre", text: /The factual source/

    get new_admin_meeting_transcript_path(@meeting)
    assert_redirected_to root_path
    assert transcript.persisted?
  end

  test "unrelated users cannot read transcript content" do
    MeetingTranscripts::Create.new(
      meeting: @meeting,
      created_by: @manager,
      pasted_text: "Restricted words",
      retention_policy: "delete_after_acceptance"
    ).call

    get admin_meeting_transcript_path(@meeting)
    assert_redirected_to new_session_path

    sign_in_as(create_user_with)
    get admin_meeting_transcript_path(@meeting)
    assert_redirected_to root_path
    assert_no_match(/Restricted words/, response.body)
  end

  private

  def create_user_with(*capabilities)
    person = Person.create!(first_name: "Transcript", last_name: SecureRandom.hex(3))
    user = User.create!(person: person, email_address: "transcript-#{SecureRandom.hex(4)}@example.com", email_verified_at: Time.current)
    capabilities.each { |capability| PermissionGrant.create!(user: user, capability: capability) }
    user
  end
end
