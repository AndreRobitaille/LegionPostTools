module PasskeyEnrollment
  PENDING_COOKIE = :pending_passkey_enrollment_reauthentication
  SOURCES = %w[profile dashboard].freeze

  private

  def pending_passkey_enrollment
    enrollment = session[:pending_passkey_enrollment]
    return unless enrollment
    return enrollment if enrollment.is_a?(Hash) && enrollment["session_id"] == Current.session&.id &&
      enrollment["expires_at"].to_i > Time.current.to_i

    clear_passkey_enrollment
    nil
  end

  def start_passkey_enrollment
    clear_passkey_enrollment
    session[:pending_passkey_enrollment] = {
      "session_id" => Current.session.id,
      "source" => params[:source] == "dashboard" ? "dashboard" : "profile",
      "nickname" => params[:nickname].to_s.strip.presence,
      "expires_at" => 30.minutes.from_now.to_i
    }
  end

  def passkey_setup_path(source = pending_passkey_enrollment&.fetch("source", nil))
    source == "dashboard" ? root_path(anchor: "add-passkey") : profile_path(anchor: "add-passkey")
  end

  def retire_enrollment_email
    enrollment = session[:pending_passkey_enrollment]
    selector = enrollment["email_selector"] if enrollment.is_a?(Hash)
    selector ||= cookies.encrypted[PENDING_COOKIE] # Emails sent before inline enrollment.
    if selector.present?
      Current.session.magic_links.where(purpose: "enroll_passkey", browser_challenge_digest: MagicLink.digest(selector), used_at: nil)
        .update_all(expires_at: Time.current)
    end
    cookies.delete(PENDING_COOKIE)
  end

  def clear_passkey_enrollment
    retire_enrollment_email
    session.delete(:pending_passkey_enrollment)
    session.delete(:webauthn_registration_challenge)
    session.delete(:reauthentication_purpose) if session[:reauthentication_purpose] == "enroll_passkey"
  end
end
