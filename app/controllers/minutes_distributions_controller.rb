class MinutesDistributionsController < ApplicationController
  before_action :require_authentication
  before_action :require_distribution_authority
  before_action :set_organization
  before_action :private_response

  def show
    @settings = @organization.minutes_distribution_setting || @organization.build_minutes_distribution_setting
    @recipients = @organization.minutes_recipients.order(:office, :name, :id)
    @issues = @organization.minutes_distributions.includes(:meeting_minutes, :deliveries).order(id: :desc).limit(30)
    @events = @organization.minutes_distribution_events.includes(:actor).order(id: :desc).limit(20)
  end

  def update
    @organization.with_lock do
      settings = @organization.minutes_distribution_setting || @organization.build_minutes_distribution_setting
      attributes = params.require(:minutes_distribution_setting).permit(:post_members_list_id, :minutes_recipients_list_id,
        :template_id, :reply_to, :audiences_reviewed, :enabled, meeting_type_ids: [])
      if attributes.key?(:meeting_type_ids)
        attributes[:meeting_type_ids] = Array(attributes[:meeting_type_ids]).reject(&:blank?).map(&:to_i)
      end
      settings.update!(attributes)
      audit!("settings_updated", details: settings.saved_changes.except("updated_at"))
      unless settings.enabled?
        @organization.minutes_distributions.recoverable.update_all(state: "held", error_message: "Automatic email paused. Review before releasing this copy.")
      end
    end
    redirect_to minutes_distribution_path, notice: "Minutes email settings saved. Held mailings require a separate release."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to minutes_distribution_path, alert: error.record.errors.full_messages.to_sentence
  end

  def create_recipient
    @organization.with_lock do
      recipient = @organization.minutes_recipients.create!(recipient_params)
      audit!("recipient_added", minutes_recipient: recipient, details: recipient.snapshot)
    end
    redirect_to minutes_distribution_path, notice: "Office entry added. Enroll its address in Minutes recipients when ready."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to minutes_distribution_path, alert: error.record.errors.full_messages.to_sentence
  end

  def update_recipient
    @organization.with_lock do
      recipient = @organization.minutes_recipients.find(params[:recipient_id])
      recipient.assign_attributes(recipient_params)
      if recipient.will_save_change_to_email?
        recipient.assign_attributes(loops_contact_id: nil, enrolled_list_id: nil, enrollment_status: "not_enrolled")
      end
      recipient.save!
      audit!("recipient_updated", minutes_recipient: recipient, details: recipient.saved_changes.except("updated_at"))
    end
    redirect_to minutes_distribution_path, notice: "Office entry saved. Address changes apply to future mailings."
  rescue ActiveRecord::RecordInvalid => error
    redirect_to minutes_distribution_path, alert: error.record.errors.full_messages.to_sentence
  end

  def enroll_recipient
    @organization.with_lock do
      recipient = @organization.minutes_recipients.find(params[:recipient_id])
      MinutesDistribution::Enrollment.call(recipient)
      audit!("recipient_enrolled", minutes_recipient: recipient, details: recipient.snapshot.merge("result" => recipient.enrollment_status))
    end
    redirect_to minutes_distribution_path, notice: "Enrollment checked. Existing opt-outs remain in effect."
  rescue Loops::Client::RequestError, Loops::Client::NetworkError, KeyError => error
    redirect_to minutes_distribution_path, alert: error.message
  end

  def hold
    minutes = @organization.meeting_minutes.find(params[:minutes_id])
    reason = params[:reason].to_s.strip
    if reason.blank?
      return redirect_to admin_meeting_minutes_path(minutes.meeting), alert: "Explain why this mailing is held."
    end
    minutes.with_lock do
      audit!("hold", meeting_minutes: minutes, details: { reason: reason })
      minutes.email_distributions.recoverable.update_all(state: "held", error_message: reason)
    end
    redirect_to admin_meeting_minutes_path(minutes.meeting), notice: "Minutes email held. The meeting record is unchanged."
  end

  def release
    minutes = @organization.meeting_minutes.find(params[:minutes_id])
    unless @organization.minutes_distribution_setting&.enabled?
      return redirect_to minutes_distribution_path, alert: "Enable automatic email before releasing a held copy."
    end
    minutes.with_lock do
      audit!("release", meeting_minutes: minutes)
      latest = minutes.email_distributions.order(:id).last
      if latest&.state == "held"
        latest.update!(state: "pending", error_message: nil)
        latest.enqueue_delivery
      end
    end
    redirect_to admin_meeting_minutes_path(minutes.meeting), notice: "Mailing hold released. Only the current recorded copy can proceed."
  end

  def retry_delivery
    issue = @organization.minutes_distributions.find(params[:issue_id])
    # An expired/uncertain attempt needs provider review, never a fresh automatic key.
    issue.meeting_minutes.with_lock do
      issue.lock!
      issue.deliveries.where(status: "needs_attention").each do |delivery|
        next if delivery.first_attempt_at && delivery.first_attempt_at < MinutesDistribution::Processor::RETRY_WINDOW.ago
        delivery.update!(status: "retry", attempt_count: 0, error_message: nil)
      end
      issue.update!(state: "pending", error_message: nil) unless issue.state.in?(%w[held superseded completed])
      audit!("retry_requested", meeting_minutes: issue.meeting_minutes, details: { issue_id: issue.id })
    end
    issue.enqueue_delivery
    redirect_to minutes_distribution_path, notice: "Retry recorded. Uncertain attempts beyond the provider window still need review."
  end

  def resolve_delivery
    issue = @organization.minutes_distributions.find(params[:issue_id])
    delivery = issue.deliveries.find(params[:delivery_id])
    unless delivery.status == "needs_attention" && params[:outcome].in?(%w[sent not_sent])
      return redirect_to minutes_distribution_path, alert: "Choose the delivery outcome you verified in Loops."
    end
    issue.meeting_minutes.with_lock do
      issue.lock!
      delivery.reload
      unless delivery.status == "needs_attention"
        raise ActiveRecord::StaleObjectError.new(delivery, "resolve")
      end
      audit!("delivery_resolved", meeting_minutes: issue.meeting_minutes, details: {
        issue_id: issue.id, delivery_id: delivery.id, outcome: params[:outcome],
        previous_attempt: delivery.attributes.slice("idempotency_key", "status", "first_attempt_at", "attempt_count", "error_message")
      })
      latest = issue.meeting_minutes.email_distributions.order(:id).last
      if params[:outcome] == "sent"
        delivery.update!(status: "sent", accepted_at: delivery.first_attempt_at || Time.current, error_message: nil)
      elsif latest == issue
        delivery.update!(status: "pending", idempotency_key: SecureRandom.uuid, first_attempt_at: nil,
          attempt_count: 0, error_message: nil)
      else
        delivery.update!(status: "superseded", error_message: "Officer verified this copy was not sent; use the newer copy.")
      end
      issue.update!(state: "ready", error_message: nil) unless issue.state == "held"
      latest.enqueue_delivery
    end
    redirect_to minutes_distribution_path, notice: "Verified delivery outcome recorded. Current mail will recheck recipient choices before proceeding."
  rescue ActiveRecord::StaleObjectError
    redirect_to minutes_distribution_path, alert: "That delivery was already resolved. Review its current status."
  end

  private

  def require_distribution_authority
    return if current_user.can_manage_minutes_distribution?
    redirect_to root_path, alert: "You do not have permission to manage minutes email."
  end

  def set_organization
    @organization = Organization.first!
  end

  def private_response
    response.headers["Cache-Control"] = "private, no-store"
  end

  def recipient_params
    params.require(:minutes_recipient).permit(:name, :office, :email, :active)
  end

  def audit!(action, **attributes)
    @organization.minutes_distribution_events.create!(actor: current_user, action:, **attributes)
  end
end
