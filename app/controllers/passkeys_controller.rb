class PasskeysController < ApplicationController
  include PasskeyEnrollment

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

    current_user.passkey_credentials.create!(
      external_id: credential.id,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      nickname: params[:nickname].presence
    )

    session.delete(:pending_passkey_enrollment)
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

    credential.verify(
      session.delete(:webauthn_authentication_challenge),
      public_key: stored_credential.public_key,
      sign_count: stored_credential.sign_count,
      user_verification: true
    )

    stored_credential.update!(sign_count: credential.sign_count, last_used_at: Time.current)
    if reauthenticating?
      Current.session.reauthenticate!
      confirm_pending_official_action! if session[:reauthentication_purpose] == OfficialActionReauthenticationsController::PURPOSE
      session.delete(:reauthentication_purpose)
    else
      start_new_session_for(stored_credential.user)
    end

    render json: { status: "authenticated" }
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
    return if Current.session&.recently_authenticated?

    session.delete(:webauthn_registration_challenge)
    nickname = params[:nickname].to_s.strip.presence
    if nickname && nickname.length > 200
      return render json: { error: "Use a passkey name of 200 characters or fewer." }, status: :unprocessable_entity
    end
    session[:pending_passkey_enrollment] = {
      session_id: Current.session.id,
      nickname: nickname,
      expires_at: 30.minutes.from_now.to_i
    }
    render json: { error: "recent authentication required", confirmation_url: new_passkey_enrollment_reauthentication_path }, status: :forbidden
  end

  def reauthenticating?
    authenticated? && session[:reauthentication_purpose].in?([
      AgentAccessReauthenticationsController::PURPOSE,
      OfficialActionReauthenticationsController::PURPOSE,
      PasskeyEnrollmentReauthenticationsController::PURPOSE
    ])
  end

  def confirm_pending_official_action!
    confirmation = current_user.official_action_confirmations.find_by!(
      id: session[OfficialActionReauthenticationsController::PENDING_SESSION_KEY],
      session: Current.session
    )
    confirmation.confirm!(session: Current.session)
  end

  def public_key_credential_params
    params.require(:publicKeyCredential).permit(
      :id,
      :rawId,
      :type,
      :authenticatorAttachment,
      response: %i[
        attestationObject
        authenticatorData
        clientDataJSON
        signature
        userHandle
      ],
      clientExtensionResults: {}
    ).to_h
  end

  def render_auth_throttle
    render json: { error: "Please wait a few minutes and try again." }, status: :too_many_requests
  end
end
