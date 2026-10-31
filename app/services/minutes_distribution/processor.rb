class MinutesDistribution::Processor
  MAX_PAYLOAD_BYTES = 4_000_000
  RETRY_WINDOW = 23.hours
  LOCK_NAMESPACE = 0x4D494E45

  def initialize(issue, client: nil, renderer: MeetingMinutesPdf)
    @issue = issue
    @client = client
    @renderer = renderer
  end

  def call
    # A session advisory lock serializes dispatch without keeping submission markers
    # in an uncommitted transaction across network I/O. A crashed worker leaves its
    # committed key/first-attempt marker for recovery, and PostgreSQL releases its lock.
    MinutesDistribution.connection_pool.with_connection do |connection|
      key = @issue.meeting_minutes_id
      locked = connection.select_value("SELECT pg_try_advisory_lock(#{LOCK_NAMESPACE}, #{Integer(key)})")
      return unless locked
      begin
        @issue.meeting_minutes.email_distributions.order(:id).each do |issue|
          next unless issue.state.in?(%w[pending ready])
          process(issue)
        end
      ensure
        connection.execute("SELECT pg_advisory_unlock(#{LOCK_NAMESPACE}, #{Integer(key)})")
      end
    end
  end

  private

  def process(issue)
    settings = issue.organization.minutes_distribution_setting
    if !settings&.enabled? || MinutesDistributionEvent.held?(issue.meeting_minutes)
      issue.update!(state: "held", error_message: "Mailing paused. Review this copy before releasing it.")
      return
    end
    client = @client || Loops::Client.new
    client.open do |session|
      MinutesDistribution::Groups.verify!(settings, session)
      return unless prepare(issue, settings)
      issue.deliveries.unresolved.order(:id).each do |delivery|
        deliver(issue, delivery, session)
      end
    end
    return if issue.reload.state.in?(%w[held superseded])

    states = issue.deliveries.reload.pluck(:status)
    state = if states.include?("needs_attention")
      "needs_attention"
    elsif states.intersect?(%w[pending submitting retry])
      "ready"
    else
      "completed"
    end
    issue.update!(state:, error_message: nil)
  rescue ActiveStorage::FileNotFoundError, ActiveStorage::IntegrityError
    issue.update!(state: "needs_attention", error_message: "The saved PDF is unavailable or damaged. Review the stored copy before retrying.")
  rescue Loops::Client::NetworkError, Loops::Client::RequestError, BrowserPdfRenderer::GenerationError, KeyError => error
    issue.update!(error_message: error.message)
  end

  def prepare(issue, settings)
    return false unless refresh_context(issue, settings)
    if issue.first_submitted_at && !issue.pdf.attached?
      issue.update!(state: "needs_attention", error_message: "The saved submitted PDF is missing. Review the stored copy before any retry.")
      return false
    end

    unless issue.pdf.attached?
      bytes = @renderer.render_distribution(issue: issue)
      raise BrowserPdfRenderer::GenerationError, "The minutes renderer did not return a PDF." unless bytes.start_with?("%PDF")
      issue.pdf.attach(io: StringIO.new(bytes), filename: issue.filename, content_type: "application/pdf")
      issue.update!(pdf_sha256: Digest::SHA256.hexdigest(bytes))
    end
    return false if issue.reload.state.in?(%w[held superseded])

    issue.update!(state: "ready")
    true
  end

  def refresh_context(issue, settings)
    # Refresh authority only before any provider submission; all subsequent retries
    # reuse the exact frozen cover, template and PDF bytes.
    current = false
    issue.meeting_minutes.with_lock do
      issue.reload
      next if issue.state.in?(%w[held superseded])
      if issue.first_submitted_at
        current = true
        next
      end
      if issue.meeting_minutes.current_revision_id != issue.minutes_revision_id
        issue.deliveries.unresolved.update_all(status: "superseded")
        issue.update!(state: "superseded")
        next
      end
      context = MinutesDistribution::Document.context(issue.meeting_minutes)
      if issue.document_context != context || issue.template_id != settings.template_id || issue.reply_to != settings.reply_to
        issue.pdf.purge if issue.pdf.attached?
        issue.update!(document_context: context, template_id: settings.template_id,
          minutes_list_id: settings.minutes_recipients_list_id, post_members_list_id: settings.post_members_list_id,
          reply_to: settings.reply_to, filename: filename(issue, context), pdf_sha256: nil)
        issue.deliveries.each { |delivery| delivery.update!(variables: MinutesDistribution::Message.variables(issue, delivery)) }
      end
      current = true
    end
    current
  end

  def filename(issue, context)
    payload = issue.minutes_revision.payload
    suffix = context.fetch("status") == "membership_approved" ? "official-minutes" : "attested-minutes"
    "#{payload.fetch('title').parameterize}-#{Time.zone.parse(payload.fetch('starts_at')).to_date.iso8601}-#{suffix}.pdf"
  end

  def deliver(issue, delivery, client)
    if earlier_submission_unresolved?(issue, delivery)
      delivery.update!(error_message: "Waiting for the earlier delivery to this address to be checked.")
      return
    end
    if delivery.attempt_count >= 3
      delivery.update!(status: "needs_attention", error_message: "Three delivery attempts have failed. Review before retrying.")
      return
    end
    # Pending older content can be superseded; an uncertain provider submission must
    # first be resolved with its existing key, before newer content can be dispatched.
    if delivery.first_attempt_at && delivery.first_attempt_at < RETRY_WINDOW.ago
      delivery.update!(status: "needs_attention", error_message: "The provider retry window expired. Check delivery in Loops before any further send.")
      return
    end
    return unless eligible?(issue, delivery, client)
    last_sent = MinutesEmailDelivery.joins(:minutes_distribution)
      .where(minutes_distributions: { meeting_minutes_id: issue.meeting_minutes_id })
      .where(email: delivery.email, status: "sent").where.not(id: delivery.id).order(accepted_at: :desc, id: :desc).first
    if !delivery.first_attempt_at && last_sent&.minutes_distribution&.content_digest == issue.content_digest
      delivery.update!(status: "unchanged", error_message: nil)
      return
    end
    payload = MinutesDistribution::Message.payload(issue, delivery)
    if JSON.generate(payload).bytesize >= MAX_PAYLOAD_BYTES
      delivery.update!(status: "needs_attention", error_message: "The PDF email exceeds Loops' 4 MB request limit.")
      return
    end
    claimed = claim(issue, delivery)
    return unless claimed

    client.send_transactional(payload, idempotency_key: delivery.idempotency_key)
    delivery.update!(status: "sent", accepted_at: Time.current, error_message: nil)
  rescue Loops::Client::NetworkError => error
    delivery.update!(status: "retry", error_message: error.message)
  rescue Loops::Client::RequestError => error
    status = error.status == 429 || error.status.to_i >= 500 ? "retry" : "needs_attention"
    delivery.update!(status:, error_message: error.message)
  end

  def eligible?(issue, delivery, client)
    if local_recipients(issue, delivery).empty? || delivery.loops_contact_id.blank?
      skip_changed_recipient(delivery)
      return false
    end
    contact = client.find_contact(email: delivery.email)
    if !contact || contact["id"] != delivery.loops_contact_id || contact["subscribed"] != true ||
        contact.fetch("mailingLists", {})[issue.minutes_list_id] != true ||
        contact["optInStatus"].in?(%w[pending rejected]) || client.suppressed?(email: delivery.email)
      delivery.update!(status: delivery.first_attempt_at ? "needs_attention" : "skipped",
        error_message: "Current Loops identity, subscription or suppression does not permit this email.")
      return false
    end
    true
  end

  def claim(issue, delivery)
    claimed = false
    issue.meeting_minutes.with_lock do
      issue.reload
      delivery.reload
      next if issue.state.in?(%w[held superseded])
      next unless delivery.status.in?(%w[pending submitting retry])
      settings = MinutesDistributionSetting.lock.find_by(organization_id: issue.organization_id)
      if !settings&.enabled? || MinutesDistributionEvent.held?(issue.meeting_minutes)
        issue.update!(state: "held")
        next
      end
      if delivery.loops_contact_id.blank? || local_recipients(issue, delivery).lock.to_a.empty?
        skip_changed_recipient(delivery)
        next
      end
      # If approval changed while the PDF was rendering, refresh before starting mail.
      if !issue.first_submitted_at &&
          issue.document_context != MinutesDistribution::Document.context(issue.meeting_minutes)
        next
      end
      issue.update!(first_submitted_at: Time.current) unless issue.first_submitted_at
      delivery.update!(status: "submitting", first_attempt_at: delivery.first_attempt_at || Time.current,
        attempt_count: delivery.attempt_count + 1)
      claimed = true
    end
    claimed
  end

  def local_recipients(issue, delivery)
    ids = delivery.recipient_snapshot.map { |entry| entry.fetch("id") }
    issue.organization.minutes_recipients.active.where(id: ids, email: delivery.email,
      loops_contact_id: delivery.loops_contact_id, enrolled_list_id: issue.minutes_list_id)
  end

  def skip_changed_recipient(delivery)
    delivery.update!(status: delivery.first_attempt_at ? "needs_attention" : "skipped",
      error_message: "The original recipient is paused, changed or not enrolled.")
  end

  def earlier_submission_unresolved?(issue, delivery)
    MinutesEmailDelivery.joins(:minutes_distribution)
      .where(minutes_distributions: { meeting_minutes_id: issue.meeting_minutes_id })
      .where("minutes_distributions.id < ?", issue.id)
      .where(email: delivery.email, status: %w[submitting retry needs_attention])
      .where.not(first_attempt_at: nil).exists?
  end
end
