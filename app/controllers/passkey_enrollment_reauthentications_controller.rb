class PasskeyEnrollmentReauthenticationsController < ApplicationController
  include PasskeyEnrollment
  include PasskeyAssertion

  PURPOSE = "enroll_passkey"

  before_action :require_authentication
  before_action :prepare_enrollment, only: %i[create passkey_options]
  before_action :require_pending_enrollment, except: :destroy
  before_action :no_store

  rate_limit to: 5,
    within: 5.minutes,
    only: :create,
    name: :passkey_enrollment_reauthentication_request,
    by: -> { "#{current_user.id}:#{request.remote_ip}" },
    with: :redirect_after_auth_throttle

  rate_limit to: 10,
    within: 5.minutes,
    only: :verify,
    name: :passkey_enrollment_reauthentication_code,
    by: -> { "#{current_user.id}:#{request.remote_ip}:#{pending_selector_fingerprint}" },
    with: :redirect_after_auth_throttle

  rate_limit to: 30,
    within: 5.minutes,
    only: :magic_link,
    name: :passkey_enrollment_reauthentication_link,
    by: -> { "#{current_user.id}:#{request.remote_ip}" },
    if: -> { request.post? },
    with: :redirect_after_auth_throttle

  rate_limit to: 20, within: 5.minutes, only: %i[passkey_options passkey], with: -> { head :too_many_requests }

  def new
    redirect_to passkey_setup_path
  end

  def create
    challenge = MagicLink.create_for!(current_user, purpose: PURPOSE, session: Current.session)
    MailDelivery.deliver_magic_link(
      user: current_user,
      login_url: magic_link_passkey_enrollment_reauthentication_url(token: challenge.token),
      login_code: MagicLink.format_code(challenge.login_code)
    )
    retire_enrollment_email
    pending_passkey_enrollment["email_selector"] = challenge.browser_challenge
    pending_passkey_enrollment["email_expires_at"] = challenge.expires_at.to_i
    redirect_to passkey_setup_path, status: :see_other
  rescue MailDelivery::DeliveryError => error
    Rails.logger.error("Passkey enrollment confirmation email failed status=#{error.status || 'unavailable'}")
    return_to_setup_with_error("We could not send that email. Try again in a few minutes.")
  end

  def verify
    user = MagicLink.consume_code!(browser_challenge: pending_selector, code: params[:code], purpose: PURPOSE, session: Current.session)
    return complete_reauthentication if user == current_user

    return_to_setup_with_error("Check the code or send a new one.")
  end

  def magic_link
    return render :magic_link if request.get? || request.head?

    selector = pending_selector
    user = MagicLink.consume!(params[:token], purpose: PURPOSE, session: Current.session,
      browser_challenge_digest: MagicLink.digest(selector)) if selector.present?
    return complete_reauthentication if user == current_user

    return_to_setup_with_error("This link has expired or was replaced. Request a new code.")
  end

  def passkey_options
    options = WebAuthn::Credential.options_for_get(allow: current_user.passkey_credentials.pluck(:external_id), user_verification: "required")
    pending_passkey_enrollment["assertion_challenge"] = options.challenge
    render json: options
  end

  def passkey
    challenge = pending_passkey_enrollment.delete("assertion_challenge")
    return head :unprocessable_entity unless challenge

    credential = WebAuthn::Credential.from_get(public_key_credential_params)
    stored = current_user.passkey_credentials.find_by(external_id: credential.id)
    return head :unauthorized unless stored

    verify_passkey_assertion!(credential, stored, challenge)
    complete_reauthentication
  rescue WebAuthn::Error
    head :unauthorized
  end

  def destroy
    destination = passkey_setup_path
    clear_passkey_enrollment
    redirect_to destination, status: :see_other
  end

  private

  def prepare_enrollment
    return unless SOURCES.include?(params[:source])
    if params[:nickname].to_s.length > 200
      return head :unprocessable_entity
    end
    start_passkey_enrollment
  end

  def require_pending_enrollment
    return if pending_passkey_enrollment

    if request.format.json?
      render json: { error: "Passkey setup expired." }, status: :unprocessable_entity
    else
      redirect_to profile_path, alert: "Start adding your passkey again from Profile."
    end
  end

  def pending_selector
    pending_passkey_enrollment&.fetch("email_selector", nil) || cookies.encrypted[PENDING_COOKIE]
  end

  def pending_selector_fingerprint
    MagicLink.digest(pending_selector.presence || "missing").first(16)
  end

  def redirect_after_auth_throttle
    return_to_setup_with_error("Please wait a few minutes and try again.")
  end

  def return_to_setup_with_error(message)
    redirect_to passkey_setup_path, flash: { passkey_error: message }
  end

  def complete_reauthentication
    Current.session.reauthenticate!
    retire_enrollment_email
    pending_passkey_enrollment["confirmed"] = true
    pending_passkey_enrollment.except!("assertion_challenge", "email_selector", "email_expires_at")
    session.delete(:reauthentication_purpose) if session[:reauthentication_purpose] == PURPOSE
    if request.format.json?
      render json: { redirect_url: passkey_setup_path }
    else
      redirect_to passkey_setup_path, status: :see_other
    end
  end
end
