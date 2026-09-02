class OfficialActionReauthenticationsController < ApplicationController
  PURPOSE = "official_minutes_action"
  PENDING_COOKIE = :pending_official_action_reauthentication
  PENDING_SESSION_KEY = :pending_official_action_confirmation_id

  before_action :require_authentication
  before_action :set_confirmation

  helper_method :confirmation_action_label, :confirmation_return_path

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
    redirect_to confirmation_return_path(@confirmation),
      notice: "Identity confirmed. Review the exact action once more to complete it."
  end

  def confirmation_return_path(confirmation)
    meeting = confirmation.meeting_minutes.meeting
    {
      "approve" => new_admin_meeting_minutes_approval_path(meeting, confirmation_id: confirmation.id),
      "attest" => new_admin_meeting_minutes_attestation_path(meeting, confirmation_id: confirmation.id),
      "reopen" => new_admin_meeting_minutes_reopening_path(meeting, confirmation_id: confirmation.id),
      "record_membership_approval" => new_admin_meeting_minutes_membership_approval_path(meeting, confirmation_id: confirmation.id)
    }.fetch(confirmation.action)
  end

  def confirmation_action_label(confirmation)
    {
      "approve" => "Approve for Adjutant attestation",
      "attest" => "Attest and release to members",
      "reopen" => "Reopen for correction",
      "record_membership_approval" => "Record membership approval"
    }.fetch(confirmation.action)
  end

  def redirect_after_auth_throttle
    redirect_to new_official_action_reauthentication_path, alert: "Please wait a few minutes and try again."
  end
end
