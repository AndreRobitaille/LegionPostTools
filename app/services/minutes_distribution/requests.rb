module MinutesDistribution::Requests
  module_function

  # Called with the minutes locked, in the official attestation transaction. No network.
  def record_attestation(minutes)
    settings = minutes.organization.minutes_distribution_setting
    return unless settings&.includes_minutes?(minutes)

    first_issue = minutes.email_distributions.order(:id).first
    issue = minutes.email_distributions.create!(
      organization: minutes.organization, minutes_revision: minutes.current_revision,
      content_digest: MinutesDistribution::Content.digest(minutes.current_revision.payload),
      corrected: first_issue.present?, state: MinutesDistributionEvent.held?(minutes) ? "held" : "pending"
    )
    destinations = if first_issue
      first_issue.deliveries.map { |delivery| [ delivery.email, delivery.recipient_snapshot, delivery.loops_contact_id ] }
    else
      minutes.organization.minutes_recipients.active.order(:id).group_by(&:email).map do |email, recipients|
        [ email, recipients.map(&:snapshot), recipients.first.loops_contact_id ]
      end
    end
    destinations.each do |email, snapshot, contact_id|
      issue.deliveries.create!(email:, recipient_snapshot: snapshot, loops_contact_id: contact_id,
        idempotency_key: SecureRandom.uuid)
    end
    # Unattempted older copies can safely be replaced. Unknown submissions retain their
    # keys and frozen payload until resolved; later content waits behind them.
    minutes.email_distributions.where.not(id: issue.id).each do |older|
      older.deliveries.where(status: %w[pending retry], first_attempt_at: nil).update_all(status: "superseded")
      if older.state == "held"
        older.deliveries.where(status: %w[submitting retry]).where.not(first_attempt_at: nil).update_all(
          status: "needs_attention", error_message: "An earlier dispatch was paused. Verify its outcome in Loops before sending another copy to this address."
        )
      end
      older.update!(state: "superseded") unless older.deliveries.unresolved.exists? ||
        older.deliveries.where(status: "needs_attention").exists?
    end
    issue
  end
end
