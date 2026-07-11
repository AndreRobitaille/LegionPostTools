class PasskeysController < ApplicationController
  skip_before_action :redirect_to_setup_if_needed
  before_action :require_authentication, except: %i[authentication_options authentication]

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

    session[:webauthn_registration_challenge] = options.challenge
    render json: options
  end

  def registration
    credential = WebAuthn::Credential.from_create(public_key_credential_params)
    credential.verify(session.delete(:webauthn_registration_challenge), user_verification: true)

    current_user.passkey_credentials.create!(
      external_id: credential.id,
      public_key: credential.public_key,
      sign_count: credential.sign_count,
      nickname: params[:nickname].presence
    )

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

    credential.verify(
      session.delete(:webauthn_authentication_challenge),
      public_key: stored_credential.public_key,
      sign_count: stored_credential.sign_count,
      user_verification: true
    )

    stored_credential.update!(sign_count: credential.sign_count, last_used_at: Time.current)
    start_new_session_for(stored_credential.user)

    render json: { status: "authenticated" }
  rescue WebAuthn::Error
    render json: { error: "invalid passkey authentication" }, status: :unauthorized
  end

  def update
    credential = current_user.passkey_credentials.find(params[:id])
    credential.update!(nickname: params[:nickname].to_s.strip.presence)
    redirect_to settings_security_path, notice: "Passkey name updated."
  end

  def destroy
    current_user.passkey_credentials.find(params[:id]).destroy!
    redirect_to settings_security_path, notice: "Passkey removed."
  end

  private

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
