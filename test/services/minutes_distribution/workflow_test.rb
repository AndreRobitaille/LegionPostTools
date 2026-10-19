require "test_helper"
require_relative "../../support/minutes_distribution_provider"
require_relative "../../support/minutes_distribution_data"

class MinutesDistribution::WorkflowTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include MinutesDistributionData

  setup { setup_distribution }

  test "attestation saves one durable intent and sends the exact copy privately" do
    issue = nil
    assert_enqueued_with(job: MinutesDistributionJob) { issue = attest }
    original_revision = minutes.current_revision.reload.attributes
    dispatch(issue)
    assert_equal "completed", issue.reload.state
    delivery = issue.deliveries.sole
    assert_equal "sent", delivery.status
    assert_equal 1, provider.messages.size
    message = provider.messages.sole
    assert_equal "county@example.test", message.fetch(:email)
    assert_equal false, message.fetch(:addToAudience)
    assert_match(/not yet been approved by the Membership/, message.dig(:dataVariables, "cover_note"))
    assert_equal "application/pdf", message.dig(:attachments, 0, :contentType)
    assert_equal issue.pdf.download, Base64.strict_decode64(message.dig(:attachments, 0, :data))
    assert_equal Digest::SHA256.hexdigest(issue.pdf.download), issue.pdf_sha256
    assert_equal original_revision, minutes.current_revision.reload.attributes
    dispatch(issue)
    assert_equal 1, provider.attempts.size
  end

  test "PEC and monthly meeting types use the same office list and correct approval body" do
    pec = organization.meeting_types.create!(name: "PEC meeting", slug: "pec", active: true, position: 2)
    organization.minutes_distribution_setting.update!(meeting_type_ids: [ type.id, pec.id ])
    pec_body = organization.meeting_bodies.create!(name: "PEC", slug: "pec")
    meeting = create_meeting!(organization:, meeting_body: pec_body, meeting_type: pec, starts_at: 1.day.ago)
    monthly = attest
    @minutes = MeetingMinutes.create_from_meeting!(meeting:)
    pec_issue = attest
    dispatch(monthly)
    dispatch(pec_issue)
    assert_equal [ recipient.email, recipient.email ], provider.messages.map { |message| message.fetch(:email) }
    assert_match(/not yet been approved by the PEC;/, provider.messages.last.dig(:dataVariables, "cover_note"))
  end

  test "corrected copy sends after re-attestation and approval alone sends nothing" do
    first = attest
    dispatch(first)
    frozen_pdf = first.pdf.download
    second = correct("Balance: $101.")
    assert_equal 1, provider.messages.size, "Editing and re-attesting only queues work"
    dispatch(second)
    assert_equal 2, provider.messages.size
    assert_match(/Corrected minutes/, provider.messages.last.dig(:dataVariables, "subject"))
    assert_match(/replaces the earlier copy/, provider.messages.last.dig(:dataVariables, "cover_note"))
    assert_includes second.pdf.download, "$101"
    assert_equal frozen_pdf, first.reload.pdf.download
    assert_no_difference "MinutesDistribution.count" do
      approve
    end
    dispatch(second)
    assert_equal 2, provider.messages.size
    assert_equal "membership_approved", minutes.reload.status
    assert_equal "$100", first.minutes_revision.payload.to_json[/\$100/]
  end

  test "corrections adopted at the next meeting send the attested final corrected copy" do
    dispatch(attest)
    approve(corrections_pending: true)
    assert_equal "draft", minutes.reload.status
    assert_equal 1, MinutesDistribution.count
    @item.reload.update!(body: "Balance: $101.")
    final = attest
    assert_equal "membership_approved", minutes.reload.status
    dispatch(final)
    assert_equal 2, provider.messages.size
    assert_match(/approved by the Membership/, provider.messages.last.dig(:dataVariables, "cover_note"))
    assert_no_match(/not yet/, provider.messages.last.dig(:dataVariables, "cover_note"))
    assert_equal "membership_approved", final.reload.document_context.fetch("status")
    assert final.filename.end_with?("official-minutes.pdf")
  end

  test "unchanged re-attestation does not send and later return to earlier text does" do
    first = attest
    dispatch(first)
    same = correct("Balance: $100.")
    dispatch(same)
    assert_equal "unchanged", same.deliveries.sole.status
    assert_equal 1, provider.messages.size
    dispatch(correct("Balance: $101."))
    dispatch(correct("Balance: $100."))
    assert_equal 3, provider.messages.size
    assert_equal first.content_digest, minutes.email_distributions.order(:id).last.content_digest
  end

  test "first destinations stay fixed across corrected copies and office addresses remain separate" do
    add_recipient("district@example.test", office: "District Vice Commander", name: recipient.name)
    organization.minutes_recipients.create!(name: recipient.name, office: "County alternate", email: " COUNTY@example.test ",
      loops_contact_id: recipient.loops_contact_id, enrolled_list_id: "minutes", enrollment_status: "enrolled")
    first = attest
    assert_equal 2, first.deliveries.count
    assert_equal 2, first.deliveries.find_by!(email: recipient.email).recipient_snapshot.size
    recipient.update!(active: false)
    dispatch(first)
    assert_equal 2, provider.messages.size, "Another active office still authorizes the shared destination"
    add_recipient("new@example.test", office: "New officer")
    corrected = correct("Balance: $102.")
    dispatch(corrected)
    assert_equal [ "county@example.test", "district@example.test" ].sort,
      provider.messages.last(2).map { |message| message.fetch(:email) }.sort
  end

  test "a queued old copy is superseded by the newest attested text" do
    first = attest
    latest = correct("Balance: $105.")
    dispatch(first)
    assert_equal "superseded", first.reload.state
    assert_equal "superseded", first.deliveries.sole.status
    assert_equal 1, provider.messages.size
    assert_includes Base64.strict_decode64(provider.messages.sole.dig(:attachments, 0, :data)), "$105"
    assert_equal "sent", latest.deliveries.sole.status
  end

  test "lost queueing is recovered without inferring mail for historical records" do
    with_distribution_method(MinutesDistributionJob, :perform_later, ->(*) { raise "Synthetic queue unavailable" }) do
      attest
    end
    assert_equal 1, MinutesDistribution.count
    assert_enqueued_with(job: MinutesDistributionJob) { MinutesDistributionReconcileJob.perform_now }
    organization.minutes_distribution_setting.update!(enabled: false)
    correct("Balance: $106.")
    assert_equal 1, MinutesDistribution.count
  end

  test "a rolled back or stale attestation creates no mailing" do
    assert_no_difference "MinutesDistribution.count" do
      MeetingMinutes.transaction do
        attest
        raise ActiveRecord::Rollback
      end
    end
    minutes.reload
    confirmation = OfficialActionConfirmation.record_external!(minutes:, user: officer, action: "attest", evidence_note: "Synthetic stale request")
    @item.update!(body: "Balance: $109.")
    assert_raises(ActiveRecord::RecordInvalid) { minutes.attest_with_confirmation!(confirmation:) }
    assert_equal 0, MinutesDistribution.count
    assert_equal "draft", minutes.reload.status
  end

  test "timeout after provider acceptance retries exactly one frozen message with its saved key" do
    issue = attest
    provider.timeout_after_accept = true
    dispatch(issue)
    delivery = issue.deliveries.sole
    assert_equal "retry", delivery.status
    assert_equal 1, provider.messages.size
    original_payload, key = provider.attempts.sole
    approve
    organization.minutes_distribution_setting.update!(template_id: "new-template")
    dispatch(issue)
    assert_equal 2, provider.attempts.size
    assert_equal [ original_payload, key ], provider.attempts.last
    assert_equal 1, provider.messages.size
    assert_equal "sent", delivery.reload.status
  end

  test "unknown outcome beyond retry window requires review" do
    issue = attest
    provider.timeout_after_accept = true
    dispatch(issue)
    travel 24.hours do
      dispatch(issue)
      assert_equal "needs_attention", issue.reload.state
      assert_equal "needs_attention", issue.deliveries.sole.status
      assert_equal 1, provider.attempts.size
    end
  end

  test "pause opt-out suppression missing contact and changed identity stop sending" do
    %w[unsubscribed suppressed missing changed paused].each do |kind|
      add_recipient("#{kind}@example.test", office: kind)
    end
    issue = attest
    provider.contacts["unsubscribed@example.test"]["subscribed"] = false
    provider.suppressed << "suppressed@example.test"
    provider.contacts.delete("missing@example.test")
    provider.contacts["changed@example.test"]["id"] = "different-contact"
    organization.minutes_recipients.find_by!(email: "paused@example.test").update!(active: false)
    provider.contacts[recipient.email]["mailingLists"].delete("minutes")
    dispatch(issue)
    assert_equal 0, provider.messages.size
    assert_equal [ "skipped" ], issue.deliveries.distinct.pluck(:status)
    assert_equal "completed", issue.reload.state
  end

  test "approval before first send refreshes authority even when PDF preparation was delayed" do
    issue = attest
    approve
    dispatch(issue)
    assert_equal "membership_approved", issue.reload.document_context.fetch("status")
    assert_no_match(/not yet/, provider.messages.sole.dig(:dataVariables, "cover_note"))
  end

  test "global pause holds recorded work and reconciliation never releases it" do
    issue = attest
    organization.minutes_distribution_setting.update!(enabled: false)
    dispatch(issue)
    assert_equal "held", issue.reload.state
    organization.minutes_distribution_setting.update!(enabled: true)
    assert_no_enqueued_jobs { MinutesDistributionReconcileJob.perform_now }
    dispatch(issue)
    assert_empty provider.messages
  end
  test "approval during rendering refreshes the unsent PDF before a later dispatch" do
    issue = attest
    test_case = self
    renderer = Object.new
    renderer.define_singleton_method(:render_distribution) do |issue:|
      bytes = MinutesDistributionData::Renderer.render_distribution(issue:)
      test_case.approve
      bytes
    end
    MinutesDistribution::Processor.new(issue, client: provider, renderer:).call
    assert_empty provider.messages
    assert_nil issue.reload.first_submitted_at
    dispatch(issue)
    assert_equal 1, provider.messages.size
    assert_equal "membership_approved", issue.reload.document_context.fetch("status")
    assert_no_match(/not yet/, provider.messages.sole.dig(:dataVariables, "cover_note"))
  end

  test "PDF failure oversized payload and provider rejection leave attestation intact" do
    issue = attest
    renderer = Object.new
    renderer.define_singleton_method(:render_distribution) { |issue:| raise BrowserPdfRenderer::GenerationError, "Synthetic PDF failure" }
    MinutesDistribution::Processor.new(issue, client: provider, renderer:).call
    assert_equal "Synthetic PDF failure", issue.reload.error_message
    assert_empty provider.messages
    assert_equal "attested", minutes.reload.status
    renderer.define_singleton_method(:render_distribution) { |issue:| "%PDF" + "x" * 3_100_000 }
    MinutesDistribution::Processor.new(issue, client: provider, renderer:).call
    assert_equal "needs_attention", issue.reload.state
    assert_match(/4 MB/, issue.deliveries.sole.error_message)
    assert_empty provider.attempts
    assert_equal "attested", minutes.reload.status
  end

  test "partial delivery uses the last successfully sent content for each destination" do
    second = add_recipient("district@example.test", office: "District Commander")
    rejected = second.email
    provider.before_send = ->(payload) { raise Loops::Client::RequestError.new("Synthetic rejection", status: 400) if payload[:email] == rejected }
    issue = attest
    dispatch(issue)
    assert_equal "sent", issue.deliveries.find_by!(email: recipient.email).status
    assert_equal "needs_attention", issue.deliveries.find_by!(email: rejected).status
    # An officer confirmed that the rejected destination was not sent; the next
    # correction supersedes that attempt and uses its original destination list.
    issue.deliveries.find_by!(email: rejected).update!(status: "skipped")
    provider.before_send = nil
    same = correct("Balance: $100.")
    dispatch(same)
    assert_equal "unchanged", same.deliveries.find_by!(email: recipient.email).status
    assert_equal "sent", same.deliveries.find_by!(email: rejected).status
    assert_equal 2, provider.messages.size
  end

  test "an interrupted worker leaves its committed submission marker and recovers with the same key" do
    issue = attest
    crash = true
    provider.define_singleton_method(:send_transactional) do |payload, idempotency_key:|
      result = super(payload, idempotency_key:)
      if crash
        crash = false
        raise "Synthetic worker interruption after provider response"
      end
      result
    end
    assert_raises(RuntimeError) { dispatch(issue) }
    assert_equal "submitting", issue.deliveries.sole.reload.status
    assert issue.reload.first_submitted_at
    assert_equal 1, provider.messages.size
    dispatch(issue)
    assert_equal "sent", issue.deliveries.sole.reload.status
    assert_equal 1, provider.messages.size
    assert_equal 1, provider.attempts.map(&:last).uniq.size
    assert_not issue.update(document_context: { "status" => "draft" })
  end

  test "new corrected content waits for an uncertain older provider submission to resolve" do
    first = attest
    provider.timeout_after_accept = true
    dispatch(first)
    latest = correct("Balance: $117.")
    dispatch(latest)
    assert_equal 2, provider.messages.size
    assert_equal "sent", first.deliveries.sole.reload.status
    assert_equal "sent", latest.deliveries.sole.reload.status
    assert_includes Base64.strict_decode64(provider.messages.last.dig(:attachments, 0, :data)), "$117"
  end
  test "a recipient paused during provider lookups does not start dispatch" do
    issue = attest
    entry = recipient
    provider.define_singleton_method(:suppressed?) do |email:|
      entry.update!(active: false)
      false
    end
    dispatch(issue)
    assert_empty provider.messages
    assert_equal "skipped", issue.deliveries.sole.reload.status
    assert_nil issue.reload.first_submitted_at
  end

  test "a newer attestation during PDF rendering preserves superseded state and sends only current text" do
    first = attest
    test_case = self
    newer = nil
    renderer = Object.new
    renderer.define_singleton_method(:render_distribution) do |issue:|
      bytes = MinutesDistributionData::Renderer.render_distribution(issue:)
      newer = test_case.correct("Balance: $151.")
      bytes
    end
    MinutesDistribution::Processor.new(first, client: provider, renderer:).call
    assert_empty provider.messages
    assert_equal "superseded", first.reload.state
    dispatch(newer)
    assert_equal 1, provider.messages.size
    assert_includes Base64.strict_decode64(provider.messages.sole.dig(:attachments, 0, :data)), "$151"
  end

  test "one uncertain address does not delay corrected minutes for healthy addresses" do
    district = add_recipient("district@example.test", office: "District Commander")
    first = attest
    provider.timeout_after_accept = true
    dispatch(first)
    assert_equal "retry", first.deliveries.find_by!(email: recipient.email).status
    assert_equal "sent", first.deliveries.find_by!(email: district.email).status
    latest = correct("Balance: $153.")
    travel 24.hours do
      dispatch(latest)
      assert_equal "needs_attention", first.deliveries.find_by!(email: recipient.email).reload.status
      assert_equal "sent", latest.deliveries.find_by!(email: district.email).reload.status
      assert_equal "pending", latest.deliveries.find_by!(email: recipient.email).reload.status
      assert_equal 3, provider.messages.size
      assert_equal district.email, provider.messages.last.fetch(:email)
    end
  end
  test "a missing submitted attachment never regenerates a different retry document" do
    issue = attest
    provider.timeout_after_accept = true
    dispatch(issue)
    issue.pdf.purge
    dispatch(issue)
    assert_equal "needs_attention", issue.reload.state
    assert_match(/saved submitted PDF is missing/, issue.error_message)
    assert_equal 1, provider.attempts.size
    assert_not issue.pdf.attached?
  end
  test "new attestation exposes a held uncertain older dispatch for officer reconciliation" do
    first = attest
    provider.timeout_after_accept = true
    dispatch(first)
    organization.minutes_distribution_setting.update!(enabled: false)
    dispatch(first)
    assert_equal "held", first.reload.state
    organization.minutes_distribution_setting.update!(enabled: true)
    latest = correct("Balance: $157.")
    assert_equal "needs_attention", first.deliveries.sole.reload.status
    dispatch(latest)
    assert_equal 1, provider.messages.size
    assert_equal "pending", latest.deliveries.sole.reload.status
  end
end
