require "test_helper"
require_relative "../../support/minutes_distribution_provider"
require_relative "../../support/minutes_distribution_data"

class MinutesDistributionEmailWordingTest < ActiveSupport::TestCase
  include MinutesDistributionData
  setup { setup_distribution }

  test "wording is captured at attestation and editing before dispatch or retry cannot change that copy" do
    settings = organization.minutes_distribution_setting
    settings.update!(email_subject_template: "County copy — {{copy_label}} — {{meeting_date}}",
      email_cover_note_template: "Please retain the {{meeting_label}} record for {{post_name}}.")
    issue = attest
    saved_wording = issue.email_wording.deep_dup
    settings.update!(email_subject_template: "New wording — {{copy_label}}", email_cover_note_template: "New cover note")
    provider.timeout_after_accept = true
    dispatch(issue)
    original = provider.messages.sole.deep_dup
    assert_match(/County copy — Minutes —/, original.dig(:dataVariables, "subject"))
    assert_includes original.dig(:dataVariables, "cover_note"), "Please retain the"
    assert_includes original.dig(:dataVariables, "cover_note"), "Synthetic Legion Post"
    assert_includes original.dig(:dataVariables, "cover_note"), "not yet been approved"
    assert_equal saved_wording, issue.reload.email_wording
    settings.update!(email_cover_note_template: "Another later edit")
    dispatch(issue)
    assert_equal "sent", issue.deliveries.sole.reload.status
    assert_equal 1, provider.messages.size
    assert_equal original, provider.attempts.last.first
    assert_raises(ActiveRecord::RecordInvalid) { issue.update!(email_wording: settings.email_wording) }
  end

  test "new wording alone sends no duplicate and genuinely corrected text uses new wording plus automatic status" do
    settings = organization.minutes_distribution_setting
    dispatch(attest)
    settings.update!(email_subject_template: "Officer copy — {{copy_label}} — {{meeting_label}}", email_cover_note_template: "Please save this copy.")
    official_action("reopen", reason: "Review without changing minutes.")
    unchanged = attest
    dispatch(unchanged)
    assert_equal "unchanged", unchanged.deliveries.sole.reload.status
    assert_equal 1, provider.messages.size
    corrected = correct("Balance: $121.")
    dispatch(corrected)
    message = provider.messages.last.fetch(:dataVariables)
    assert_match(/Officer copy — Corrected minutes —/, message.fetch("subject"))
    assert_includes message.fetch("cover_note"), "Please save this copy."
    assert_includes message.fetch("cover_note"), MinutesDistribution::EmailTemplate::CORRECTION_NOTICE
    assert_includes message.fetch("cover_note"), "not yet been approved by the Membership"
    approve
    dispatch(corrected)
    assert_equal 2, provider.messages.size
  end

  test "older distributions with no wording snapshot keep the original corrected-copy wording" do
    dispatch(attest)
    issue = correct("Balance: $122.")
    # Represents a distribution that existed before this additive migration.
    issue.update_column(:email_wording, {})
    organization.minutes_distribution_setting.update!(email_cover_note_template: "Later custom note")
    dispatch(issue)
    message = provider.messages.last.fetch(:dataVariables)
    assert_match(/\AAttached are the corrected minutes of our /, message.fetch("cover_note"))
    assert_includes message.fetch("cover_note"), "This copy replaces the earlier copy."
    assert_not_includes message.fetch("cover_note"), "Later custom note"
  end

  test "unknown incomplete and misleading subject templates cannot be saved" do
    settings = organization.minutes_distribution_setting
    [ "No copy marker", "{{copy_label}}\nInjected header", "{{copy_label}} {{unknown}}", "{{copy_label}} {{meeting_date" ].each do |text|
      settings.email_subject_template = text
      assert_not settings.valid?, text
      assert settings.errors[:email_subject_template].any?
    end
    assert settings.update(email_subject_template: "{{ post_name }} — {{ copy_label }}", email_cover_note_template: "For {{meeting_date}}.")
  end
end
