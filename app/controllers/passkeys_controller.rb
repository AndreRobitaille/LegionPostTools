class PasskeysController < ApplicationController
  include PasskeyEnrollment
  include PasskeyAssertion

  skip_before_action :redirect_to_setup_if_needed
  before_action :require_authentication, except: %i[authentication_options authentication]

  before_action :require_recent_enrollment_authentication, only: %i[registration_options registration]

  rate_limit to: 20,
    within: 5.minutes,
    only: :authentication_options,
    name: :passkey_authentication_options,
    by: -> { request.remote_ip },
    with: :render_auth_throttle

  rate_limit to: 20,
    within: 5.minutes,
    only: :authentication,
    name: :passkey_authentication_submission,
    by: -> { request.remote_ip },
    with: :render_auth_throttle

  def index
    render json: current_user.passkey_credentials.order(:created_at).map { |credential|
      {
        id: credential.id,
        nickname: credential.nickname,
        last_used_at: credential.last_used_at,
        created_at: credential.created_at
      }
    }
  end

  def registration_options
    if SOURCES.include?(params[:source])
      attempt = pending_passkey_enrollment
      attempt = start_passkey_enrollment unless attempt && attempt["source"] == params[:source]
      attempt["nickname"] = params[:nickname].to_s.strip.presence
    end
    options = WebAuthn::Credential.options_for_create(
      user: {
        id: current_user.webauthn_id,
        name: current_user.email_address,
        display_name: current_user.person.full_name
      },
      authenticator_selection: {
        resident_key: "required",
        user_verification: "required"
      },
      exclude: current_user.passkey_credentials.pluck(:external_id)
    )

    session[:webauthn_registration_challenge] = {
      challenge: options.challenge,
      session_id: Current.session.id,
      authenticated_at: Current.session.authenticated_at.iso8601(6)
    }
    render json: options
  end

  def registration
    enrollment = session.delete(:webauthn_registration_challenge)
    unless enrollment.is_a?(Hash) &&
        enrollment["session_id"] == Current.session.id &&
        enrollment["authenticated_at"] == Current.session.authenticated_at.iso8601(6) &&
        enrollment["challenge"].present?
      return render json: { error: "invalid passkey registration" }, status: :unprocessable_entity
    end

    credential = WebAuthn::Credential.from_create(public_key_credential_params)
    credential.verify(enrollment["challenge"], user_verification: true)

    saved = current_user.passkey_credentials.create!(
      external_id: credential.id,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      nickname: params[:nickname].to_s.strip.presence
    )

    clear_passkey_enrollment
    if SOURCES.include?(params[:source])
      flash[:notice] = saved.nickname.present? ? "Passkey added: #{saved.nickname}" : "Passkey added"
    end
    render json: { status: "created" }, status: :created
  rescue WebAuthn::Error
    render json: { error: "invalid passkey registration" }, status: :unprocessable_entity
  end

  def authentication_options
    options = WebAuthn::Credential.options_for_get
    session[:webauthn_authentication_challenge] = options.challenge
    render json: options
  end

  def authentication
    credential = WebAuthn::Credential.from_get(public_key_credential_params)
    stored_credential = PasskeyCredential.find_by(external_id: credential.id)

    return render json: { error: "invalid passkey authentication" }, status: :unauthorized if stored_credential.blank?
    return render json: { error: "invalid passkey authentication" }, status: :unauthorized if stored_credential.user.disabled_at.present?
    if reauthenticating? && stored_credential.user != current_user
      return render json: { error: "invalid passkey authentication" }, status: :unauthorized
    end

    verify_passkey_assertion!(credential, stored_credential, session.delete(:webauthn_authentication_challenge))
    redirect_url = nil
    if reauthenticating?
      Current.session.reauthenticate!
      session.delete(:reauthentication_purpose)
    else
      start_new_session_for(stored_credential.user)
      if session[:mobile_authorization_return_to].present? || session[SignInReturnPath::SESSION_KEY].present?
        redirect_url = after_human_sign_in_path
      end
    end

    render json: { status: "authenticated", redirect_url: }.compact
  rescue WebAuthn::Error
    render json: { error: "invalid passkey authentication" }, status: :unauthorized
  end

  def update
    credential = current_user.passkey_credentials.find(params[:id])
    credential.update!(nickname: params[:nickname].to_s.strip.presence)
    redirect_to profile_path, notice: "Passkey name updated."
  end

  def destroy
    current_user.passkey_credentials.find(params[:id]).destroy!
    redirect_to profile_path, notice: "Passkey removed."
  end

  private

  def require_recent_enrollment_authentication
    if params[:nickname].to_s.strip.length > 200
      return render json: { error: "Use a passkey name of 200 characters or fewer." }, status: :unprocessable_entity
    end
    return if Current.session&.recently_authenticated?

    start_passkey_enrollment
    render json: { error: "recent authentication required", confirmation_url: passkey_setup_path }, status: :forbidden
  end

  def reauthenticating?
    authenticated? && session[:reauthentication_purpose].in?([
      AgentAccessReauthenticationsController::PURPOSE,
      PasskeyEnrollmentReauthenticationsController::PURPOSE
    ])
  end

  def render_auth_throttle
    render json: { error: "Please wait a few minutes and try again." }, status: :too_many_requests
  end
end
