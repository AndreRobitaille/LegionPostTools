module PasskeyEnrollment
  private

  def pending_passkey_enrollment
    enrollment = session[:pending_passkey_enrollment]
    if enrollment.is_a?(Hash) && enrollment["session_id"] == Current.session&.id &&
        enrollment["expires_at"].to_i > Time.current.to_i
      enrollment
    else
      session.delete(:pending_passkey_enrollment)
      nil
    end
  end
end
