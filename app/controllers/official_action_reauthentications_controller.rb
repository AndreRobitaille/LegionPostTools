class OfficialActionReauthenticationsController < ApplicationController
  PURPOSE = "official_minutes_action"
  PENDING_COOKIE = :pending_official_action_reauthentication
  PENDING_SESSION_KEY = :pending_official_action_confirmation_id

  before_action :require_authentication
  before_action :set_confirmation

  helper_method :confirmation_action_label, :confirmation_action_description, :confirmation_return_path

  rate_limit to: 5, within: 5.minutes, only: :create,
    name: :official_action_reauthentication_request,
    by: -> { "#{current_user.id}:#{request.remote_ip}" },
    with: :redirect_after_auth_throttle

  def new
    session[:reauthentication_purpose] = PURPOSE
  end

  def create
    session[:reauthentication_purpose] = PURPOSE
    challenge = MagicLink.create_for!(current_user, purpose: PURPOSE, session: Current.session)
    set_pending_cookie(challenge.browser_challenge)
    MailDelivery.deliver_magic_link(
      user: current_user,
      login_url: magic_link_official_action_reauthentication_url(token: challenge.token),
      login_code: MagicLink.format_code(challenge.login_code)
    )
    redirect_to new_official_action_reauthentication_path,
      notice: "Check your email for the 8-digit code or secure link."
  rescue MailDelivery::DeliveryError => error
    Rails.logger.error("Official action reauthentication email delivery failed status=#{error.status || 'unavailable'}")
    redirect_to new_official_action_reauthentication_path,
      alert: "We could not send that email. Try again in a few minutes."
  end

  def verify
    user = MagicLink.consume_code!(
      browser_challenge: cookies.encrypted[PENDING_COOKIE],
      code: params[:code],
      purpose: PURPOSE,
      session: Current.session
    )
    return complete_reauthentication if user == current_user

    redirect_to new_official_action_reauthentication_path,
      alert: "That code is invalid or expired. Request a new email and try again."
  end

  def magic_link
    return render :magic_link if request.get? || request.head?
    return head :method_not_allowed unless request.post?

    user = MagicLink.consume!(params[:token], purpose: PURPOSE, session: Current.session)
    return complete_reauthentication if user == current_user

    redirect_to new_official_action_reauthentication_path,
      alert: "That link is invalid or expired. Request a new email and try again."
  end

  private

  def set_confirmation
    @confirmation = current_user.official_action_confirmations.find_by(
      id: session[PENDING_SESSION_KEY],
      session: Current.session
    )
    return if @confirmation&.usable_by?(user: current_user, session: Current.session)

    redirect_to admin_root_path, alert: "That official action request is invalid or expired."
  end

  def set_pending_cookie(value)
    cookies.encrypted[PENDING_COOKIE] = {
      value:,
      expires: MagicLink::TOKEN_TTL.from_now,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def complete_reauthentication
    @confirmation.confirm!(session: Current.session)
    Current.session.reauthenticate!
    session.delete(:reauthentication_purpose)
    cookies.delete(PENDING_COOKIE)
    notice = @confirmation.complete_minutes_action!
    session.delete(PENDING_SESSION_KEY)
    redirect_to admin_meeting_minutes_path(@confirmation.meeting_minutes.meeting), notice:
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError => error
    session.delete(PENDING_SESSION_KEY)
    redirect_to admin_meeting_minutes_path(@confirmation.meeting_minutes.meeting),
      alert: error.record.errors.full_messages.to_sentence.presence || "The minutes changed. Review them and start the action again."
  end

  def confirmation_return_path(confirmation)
    admin_meeting_minutes_path(confirmation.meeting_minutes.meeting)
  end

  def confirmation_action_label(confirmation)
    {
      "approve" => "Send to Adjutant",
      "attest" => confirmation.meeting_minutes.pending_correction_approval ? "Confirm corrections and lock minutes" : "Attest and share with members",
      "reopen" => "Reopen for correction",
      "record_membership_approval" => "Record meeting approval"
    }.fetch(confirmation.action)
  end

  def confirmation_action_description(confirmation)
    case confirmation.action
    when "approve"
      "Your draft is handed to the Adjutant for review. The Adjutant can edit it before attesting. It stays officer-only."
    when "attest"
      if confirmation.meeting_minutes.pending_correction_approval
        "You confirm that the adopted corrections are in this copy. It becomes the official approved record and can no longer be edited."
      else
        "You electronically attest the current copy you reviewed. Members can then read it while it awaits the meeting's approval."
      end
    when "reopen"
      "The working copy becomes editable for corrections. The last attested copy stays available to members."
    when "record_membership_approval"
      payload = confirmation.action_payload
      if payload["disposition"] == "approved_as_corrected" && ActiveModel::Type::Boolean.new.cast(payload["corrections_pending"])
        "The meeting's decision is recorded. Either officer can enter its corrections, then the Adjutant confirms and locks the final copy."
      else
        "The meeting's approval is recorded against this exact attested copy. It becomes official and cannot be edited."
      end
    end
  end

  def redirect_after_auth_throttle
    redirect_to new_official_action_reauthentication_path, alert: "Please wait a few minutes and try again."
  end
end
