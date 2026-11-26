class AgentAccessReauthenticationsController < ApplicationController
  include TokenCreation
  include PasskeyAssertion

  PURPOSE = "create_agent_access_token"
  PENDING_COOKIE = :pending_agent_access_reauthentication

  before_action :require_authentication
  before_action -> { require_capability("manage_settings") }, if: :website_connection?

  rate_limit to: 5, within: 5.minutes, only: :create, name: :agent_access_reauthentication_request,
    by: -> { "#{current_user.id}:#{request.remote_ip}" }, with: :redirect_after_auth_throttle
  rate_limit to: 10, within: 5.minutes, only: :verify, name: :agent_access_reauthentication_code,
    by: -> { "#{current_user.id}:#{request.remote_ip}:#{MagicLink.digest(pending_selector).first(16)}" },
    with: :redirect_after_auth_throttle
  rate_limit to: 30, within: 5.minutes, only: :magic_link, name: :agent_access_reauthentication_link,
    by: -> { "#{current_user.id}:#{request.remote_ip}" }, if: -> { request.post? }, with: :redirect_after_auth_throttle
  rate_limit to: 20, within: 5.minutes, only: %i[passkey_options passkey], with: -> { head :too_many_requests }

  def new
    redirect_to token_creation_path
  end

  def create
    challenge = MagicLink.create_for!(current_user, purpose: PURPOSE, session: Current.session)
    MailDelivery.deliver_magic_link(
      user: current_user,
      login_url: magic_link_agent_access_reauthentication_url(token: challenge.token, kind: token_kind),
      login_code: MagicLink.format_code(challenge.login_code)
    )
    retire_pending_email
    token_setup["email_selector"] = challenge.browser_challenge
    token_setup["email_expires_at"] = challenge.expires_at.to_i
    redirect_to token_creation_path, status: :see_other
  rescue MailDelivery::DeliveryError => error
    Rails.logger.error("Token confirmation email failed status=#{error.status || 'unavailable'}")
    redirect_to token_creation_path, alert: "We could not send that email. Try again in a few minutes."
  end

  def verify
    user = MagicLink.consume_code!(browser_challenge: pending_selector, code: params[:code], purpose: PURPOSE, session: Current.session)
    return complete_reauthentication if user == current_user

    redirect_to token_creation_path, alert: "Check the code or send a new one."
  end

  def magic_link
    return render_token_setup(email_link: true) if request.get? || request.head?

    selector = pending_selector
    user = MagicLink.consume!(params[:token], purpose: PURPOSE, session: Current.session,
      browser_challenge_digest: MagicLink.digest(selector)) if selector.present?
    return complete_reauthentication if user == current_user

    redirect_to token_creation_path, alert: "This link has expired or was replaced. Request a new code."
  end

  def passkey_options
    options = WebAuthn::Credential.options_for_get(allow: current_user.passkey_credentials.pluck(:external_id), user_verification: "required")
    token_setup["passkey"] = { "challenge" => options.challenge, "expires_at" => MagicLink::TOKEN_TTL.from_now.to_i,
      "session_id" => Current.session.id }
    render json: options
  end

  def passkey
    pending = token_setup.delete("passkey")
    return head :unprocessable_entity unless pending && pending["session_id"] == Current.session.id && pending["expires_at"] > Time.current.to_i

    credential = WebAuthn::Credential.from_get(public_key_credential_params)
    stored = current_user.passkey_credentials.find_by(external_id: credential.id)
    return head :unauthorized unless stored

    verify_passkey_assertion!(credential, stored, pending.fetch("challenge"))
    complete_reauthentication
  rescue WebAuthn::Error
    head :unauthorized
  end

  def destroy
    retire_pending_email
    clear_token_setup
    redirect_to token_list_path, status: :see_other
  end

  private

  # Existing email links used the session flag and a separate encrypted cookie.
  def website_connection?
    params[:kind].present? ? params[:kind] == "website" : session[:website_token_reauthentication] == true
  end

  def pending_selector
    token_setup["email_selector"] || (cookies.encrypted[PENDING_COOKIE] if params[:kind].blank?)
  end

  def retire_pending_email
    selector = pending_selector
    if selector.present?
      Current.session.magic_links.where(purpose: PURPOSE, browser_challenge_digest: MagicLink.digest(selector), used_at: nil)
        .update_all(expires_at: Time.current)
    end
    token_setup.delete("email_selector")
    token_setup.delete("email_expires_at")
    cookies.delete(PENDING_COOKIE)
  end

  def redirect_after_auth_throttle
    redirect_to token_creation_path, alert: "Please wait a few minutes and try again."
  end

  def complete_reauthentication
    Current.session.reauthenticate!
    retire_pending_email
    token_setup.delete("passkey")
    session.delete(:website_token_reauthentication)
    if request.format.json?
      render json: { redirect_url: token_creation_path }
    else
      redirect_to token_creation_path, status: :see_other
    end
  end
end
