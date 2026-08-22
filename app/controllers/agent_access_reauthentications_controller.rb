class AgentAccessReauthenticationsController < ApplicationController
  PURPOSE = "create_agent_access_token"
  PENDING_COOKIE = :pending_agent_access_reauthentication

  before_action :require_authentication

  rate_limit to: 5,
    within: 5.minutes,
    only: :create,
    name: :agent_access_reauthentication_request,
    by: -> { "#{current_user.id}:#{request.remote_ip}" },
    with: :redirect_after_auth_throttle

  rate_limit to: 10,
    within: 5.minutes,
    only: :verify,
    name: :agent_access_reauthentication_code,
    by: -> { "#{current_user.id}:#{request.remote_ip}:#{pending_selector_fingerprint}" },
    with: :redirect_after_auth_throttle

  def new
    session[:reauthentication_purpose] = PURPOSE
  end

  def create
    session[:reauthentication_purpose] = PURPOSE
    challenge = MagicLink.create_for!(current_user, purpose: PURPOSE, session: Current.session)
    set_pending_cookie(challenge.browser_challenge)
    MailDelivery.deliver_agent_access_confirmation(
      user: current_user,
      confirmation_code: MagicLink.format_code(challenge.login_code)
    )
    redirect_to new_agent_access_reauthentication_path,
      notice: "Check your email for the 8-digit code."
  end

  def verify
    user = MagicLink.consume_code!(
      browser_challenge: cookies.encrypted[PENDING_COOKIE],
      code: params[:code],
      purpose: PURPOSE,
      session: Current.session
    )

    if user == current_user
      Current.session.reauthenticate!
      session.delete(:reauthentication_purpose)
      cookies.delete(PENDING_COOKIE)
      redirect_to new_agent_access_token_path, notice: "Identity confirmed. You may create an agent token now."
    else
      redirect_to new_agent_access_reauthentication_path,
        alert: "That code is invalid or expired. Request a new email and try again."
    end
  end

  private

  def set_pending_cookie(value)
    cookies.encrypted[PENDING_COOKIE] = {
      value: value,
      expires: MagicLink::TOKEN_TTL.from_now,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def pending_selector_fingerprint
    MagicLink.digest(cookies.encrypted[PENDING_COOKIE].presence || "missing").first(16)
  end

  def redirect_after_auth_throttle
    redirect_to new_agent_access_reauthentication_path, alert: "Please wait a few minutes and try again."
  end
end
