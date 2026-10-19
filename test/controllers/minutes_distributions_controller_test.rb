require "test_helper"
require_relative "../support/minutes_distribution_provider"
require_relative "../support/minutes_distribution_data"

class MinutesDistributionsControllerTest < ActionDispatch::IntegrationTest
  include MinutesDistributionData
  setup do
    setup_distribution
    Installation.singleton.update!(setup_completed_at: Time.current)
    @session_record = sign_in_as(officer)
  end

  test "recipient management persists separate offices then pause and address changes affect subsequent dispatch" do
    get minutes_distribution_path
    assert_response :success
    assert_equal "private, no-store", response.headers["Cache-Control"]
    assert_select "meta[name='turbo-cache-control'][content='no-cache']"
    assert_select ".minutes-email-groups", text: /Post members.*Roster sync.*Minutes recipients/m
    post create_recipient_minutes_distribution_path, params: { minutes_recipient: {
      name: recipient.name, office: "District Vice Commander", email: "district@example.test" } }
    assert_redirected_to minutes_distribution_path
    added = organization.minutes_recipients.find_by!(office: "District Vice Commander")
    assert_nil added.loops_contact_id
    fake_provider = provider
    with_stubbed_class_method(Loops::Client, :new, ->(*) { fake_provider }) do
      post enroll_recipient_minutes_distribution_path(added)
    end
    assert_equal "enrolled", added.reload.enrollment_status
    issue = attest
    patch recipient_minutes_distribution_path(recipient), params: { minutes_recipient: { active: false } }
    patch recipient_minutes_distribution_path(added), params: { minutes_recipient: { email: "new-district@example.test" } }
    dispatch(issue)
    assert_empty provider.messages
    get minutes_distribution_path
    assert_response :success
    assert_select ".minutes-email-recipient", text: /County Commander.*Paused/m
    assert_select ".minutes-email-recipient", text: /District Vice Commander.*new-district@example.test.*Not enrolled/m
    assert_nil added.reload.loops_contact_id
    assert_equal 4, organization.minutes_distribution_events.count
  end

  test "current position authority works and its removal immediately denies all recipient and hold actions" do
    officer.permission_grants.destroy_all
    title = organization.position_titles.create!(name: "Adjutant", display_order: 1)
    title.position_capability_grants.create!(capability: "attest_minutes")
    assignment = title.position_assignments.create!(person: officer.person, starts_on: 1.year.ago.to_date)
    get minutes_distribution_path
    assert_response :success
    assignment.update!(ends_on: Organization.current_local_date - 1)
    before = recipient.reload.attributes
    get minutes_distribution_path
    assert_redirected_to root_path
    patch recipient_minutes_distribution_path(recipient), params: { minutes_recipient: { active: false } }
    assert_redirected_to root_path
    post hold_minutes_distribution_path(minutes_id: minutes.id), params: { reason: "Unapproved hold" }
    assert_redirected_to root_path
    patch wording_minutes_distribution_path, params: { minutes_distribution_setting: { email_cover_note_template: "Denied", lock_version: 0 } }
    assert_redirected_to root_path
    assert_equal before, recipient.reload.attributes
    assert_empty organization.minutes_distribution_events
  end

  test "a draft editing grant alone cannot view or manage external recipients" do
    officer.permission_grants.where.not(capability: "manage_minutes").destroy_all
    get minutes_distribution_path
    assert_redirected_to root_path
    assert_no_difference "MinutesRecipient.count" do
      post create_recipient_minutes_distribution_path, params: { minutes_recipient: { name: "Denied", office: "Denied", email: "denied@example.test" } }
    end
  end

  test "global pause saves held work and resuming requires explicit release" do
    issue = attest
    patch minutes_distribution_path, params: { minutes_distribution_setting: settings_params.merge(enabled: false) }
    assert_equal "held", issue.reload.state
    patch minutes_distribution_path, params: { minutes_distribution_setting: settings_params.merge(enabled: true) }
    dispatch(issue)
    assert_empty provider.messages
    post release_minutes_distribution_path(minutes_id: minutes.id)
    assert_redirected_to admin_meeting_minutes_path(minutes.meeting)
    dispatch(issue)
    assert_equal 1, provider.messages.size
  end

  test "meeting hold applies before attestation and preserves the record" do
    post hold_minutes_distribution_path(minutes_id: minutes.id), params: { reason: "Check restricted business" }
    assert MinutesDistributionEvent.held?(minutes)
    issue = attest
    assert_equal "held", issue.state
    assert_equal "attested", minutes.reload.status
    dispatch(issue)
    assert_empty provider.messages
    get admin_meeting_minutes_path(minutes.meeting)
    assert_select "section[aria-label='Minutes email']", text: /Mailing held for officer review/
    post release_minutes_distribution_path(minutes_id: minutes.id)
    dispatch(issue)
    assert_equal 1, provider.messages.size
  end

  test "existing attestation confirmation discloses outside distribution and completing it saves email intent" do
    post admin_meeting_minutes_attestation_path(minutes.meeting)
    assert_redirected_to new_official_action_reauthentication_path
    get new_official_action_reauthentication_path
    assert_response :success
    assert_select ".official-confirmation-summary", text: /Minutes email:.*1 email address.*designated outside offices/m
    challenge = MagicLink.create_for!(officer, purpose: "official_minutes_action", session: @session_record)
    assert_difference "MinutesDistribution.count", 1 do
      post magic_link_official_action_reauthentication_path, params: { token: challenge.token }
    end
    assert_redirected_to admin_meeting_minutes_path(minutes.meeting)
    assert_equal "attested", minutes.reload.status
    issue = minutes.email_distributions.sole
    dispatch(issue)
    get admin_meeting_minutes_path(minutes.meeting)
    assert_select "section[aria-label='Minutes email']", text: /Sent to Loops for 1 address/
    assert_equal "sent", issue.deliveries.sole.reload.status
    assert_equal 1, provider.messages.size
  end

  test "cross organization recipients and meeting holds are not accessible" do
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    outsider = other.minutes_recipients.create!(name: "Other Officer", office: "County", email: "other@example.test")
    patch recipient_minutes_distribution_path(outsider), params: { minutes_recipient: { active: false } }
    assert_response :not_found
    assert outsider.reload.active?
  end

  test "an officer can reconcile an expired unknown outcome without sending the old copy again" do
    first = attest
    provider.timeout_after_accept = true
    dispatch(first)
    corrected = correct("Balance: $119.")
    travel 24.hours do
      dispatch(corrected)
      assert_equal 1, provider.messages.size
      delivery = first.deliveries.sole
      assert_equal "needs_attention", delivery.reload.status
      post resolve_delivery_minutes_distribution_path(issue_id: first.id, delivery_id: delivery.id), params: { outcome: "sent" }
      assert_equal "sent", delivery.reload.status
      dispatch(corrected)
      assert_equal 2, provider.messages.size
      assert_equal "sent", corrected.deliveries.sole.reload.status
      assert organization.minutes_distribution_events.where(action: "delivery_resolved").exists?
    end
  end

  test "verified non-delivery creates an audited fresh key for the same frozen copy" do
    issue = attest
    provider.timeout_after_accept = true
    dispatch(issue)
    delivery = issue.deliveries.sole
    original_key = delivery.idempotency_key
    original_pdf = issue.pdf.download
    travel 24.hours do
      dispatch(issue)
      # Model the provider review finding no message; the fake had accepted one,
      # so clear only its synthetic inbox to represent the verified outcome.
      provider.messages.clear
      post resolve_delivery_minutes_distribution_path(issue_id: issue.id, delivery_id: delivery.id), params: { outcome: "not_sent" }
      assert_not_equal original_key, delivery.reload.idempotency_key
      assert_nil delivery.first_attempt_at
      dispatch(issue)
      assert_equal 1, provider.messages.size
      assert_equal original_pdf, issue.reload.pdf.download
      assert_equal original_key, organization.minutes_distribution_events.last.details.dig("previous_attempt", "idempotency_key")
    end
  end

  test "a position belonging to another organization does not grant this Post's recipient access" do
    officer.permission_grants.destroy_all
    other = Organization.create!(name: "Other Post", unit_type: "american_legion_post", timezone: "America/Chicago")
    position = other.position_titles.create!(name: "Adjutant", display_order: 1)
    position.position_capability_grants.create!(capability: "attest_minutes")
    position.position_assignments.create!(person: officer.person, starts_on: 1.year.ago.to_date)
    get minutes_distribution_path
    assert_redirected_to root_path
    assert_not officer.can_manage_minutes_distribution?(organization: organization)
    assert officer.can_manage_minutes_distribution?(organization: other)
  end

  test "saved settings and email wording require an explicit edit mode" do
    get minutes_distribution_path
    assert_select "a", text: "Edit delivery settings"
    assert_select "a", text: "Edit email wording"
    assert_select "input[name='minutes_distribution_setting[reply_to]']", count: 0
    assert_select "input[name='minutes_distribution_setting[email_subject_template]']", count: 0
    assert_select "code.minutes-email-variable", text: "{{post_name}}"
    assert_no_match(/General campaigns, scheduled sends/, response.body)
    get minutes_distribution_path(edit: "delivery")
    assert_select "input[name='minutes_distribution_setting[reply_to]']", value: "reply@example.test"
    assert_select "input[name='minutes_distribution_setting[post_members_list_id]']", count: 0
    assert_select "label", text: /I checked that regular Post emails in Loops use the Post members list/
    assert_select "input[name='minutes_distribution_setting[email_subject_template]']", count: 0
  end

  test "wording updates persist and cannot alter delivery choices or send mail" do
    settings = organization.minutes_distribution_setting
    patch wording_minutes_distribution_path, params: { minutes_distribution_setting: {
      email_subject_template: "County copy — {{copy_label}} — {{meeting_date}}",
      email_cover_note_template: "Please retain these minutes for {{post_name}}.", lock_version: settings.lock_version,
      enabled: false, minutes_recipients_list_id: "wrong", meeting_type_ids: [] } }
    assert_redirected_to minutes_distribution_path
    settings.reload
    assert settings.enabled?
    assert_equal "minutes", settings.minutes_recipients_list_id
    assert_equal [ type.id ], settings.meeting_type_ids
    assert_equal "Please retain these minutes for {{post_name}}.", settings.email_cover_note_template
    get minutes_distribution_path
    assert_select ".minutes-email-template", text: /County copy/
    assert_empty organization.minutes_distributions
    assert_empty provider.messages
    assert_equal "email_wording_updated", organization.minutes_distribution_events.sole.action
    patch minutes_distribution_path, params: { minutes_distribution_setting: settings_params.merge(email_cover_note_template: "Not permitted here") }
    assert_equal "Please retain these minutes for {{post_name}}.", settings.reload.email_cover_note_template
  end

  test "invalid wording keeps entered text visible without saving or sending" do
    patch wording_minutes_distribution_path, params: { minutes_distribution_setting: {
      email_subject_template: "{{copy_label}} — {{meeting_date}}", email_cover_note_template: "Please retain {{private_roster}}.",
      lock_version: organization.minutes_distribution_setting.lock_version } }
    assert_response :unprocessable_entity
    assert_select "[role='alert']", text: /Unknown variable \{\{private_roster\}\}/
    assert_select "textarea", text: "Please retain {{private_roster}}."
    assert_nil organization.minutes_distribution_setting.reload.email_cover_note_template
    assert_empty organization.minutes_distribution_events
    assert_empty provider.messages
  end

  test "stale or missing form versions cannot overwrite saved changes" do
    settings = organization.minutes_distribution_setting
    old_version = settings.lock_version
    settings.update!(reply_to: "new-reply@example.test")
    [ old_version, nil ].each do |version|
      patch minutes_distribution_path, params: { minutes_distribution_setting: { reply_to: "stale@example.test", lock_version: version } }
      assert_response :conflict
      assert_select "a", text: "Reload latest settings"
      assert_select "input[type='submit'][disabled]"
      assert_equal "new-reply@example.test", settings.reload.reply_to
      patch wording_minutes_distribution_path, params: { minutes_distribution_setting: {
        email_subject_template: "Stale — {{copy_label}}", email_cover_note_template: "Stale", lock_version: version } }
      assert_response :conflict
      assert_nil settings.reload.email_cover_note_template
    end
    assert_empty organization.minutes_distribution_events
  end

  private

  def settings_params
    organization.minutes_distribution_setting.reload.attributes.slice("post_members_list_id", "minutes_recipients_list_id", "template_id", "reply_to", "audiences_reviewed", "meeting_type_ids", "lock_version")
  end
end
