class ApplicationController < ActionController::Base
  SESSION_INACTIVITY_LIMIT = 180.days
  SESSION_TOUCH_INTERVAL = 15.minutes

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :authenticated?, :officer?

  before_action :redirect_to_setup_if_needed
  before_action :resume_session

  def current_user
    Current.session&.user
  end

  def authenticated?
    current_user.present?
  end

  def officer?
    current_user&.can?("manage_people") || current_user&.can?("manage_settings")
  end

  def require_authentication
    return if authenticated?

    redirect_to new_session_path, alert: "You must sign in first."
  end

  def require_capability(capability)
    require_authentication
    return if performed?
    return if current_user.can?(capability)

    redirect_to root_path, alert: "You do not have permission to open that page."
  end

  def start_new_session_for(user)
    reset_session
    session = Session.create!(user: user, ip_address: request.remote_ip, user_agent: request.user_agent, last_seen_at: Time.current)
    cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax, secure: Rails.env.production? }
    Current.session = session
  end

  def terminate_current_session
    Current.session&.destroy!
    Current.session = nil
    cookies.delete(:session_id)
  end

  def redirect_to_setup_if_needed
    return if controller_name == "setup"
    return if setup_complete?
    return if setup_recovery_installed?

    redirect_to new_setup_path
  end

  def resume_session
    return if Current.session.present?

    session_id = cookies.signed[:session_id]
    return if session_id.blank?

    session = Session.find_by(id: session_id)
    return clear_session_cookie if session.blank?

    if session.user.disabled_at.present?
      session.destroy!
      clear_session_cookie
      return
    end

    if session_inactive_too_long?(session)
      session.destroy!
      clear_session_cookie
      return
    end

    touch_session_if_needed(session)
    Current.session = session
  end

  private

  def setup_complete?
    Installation.setup_completed?
  end

  def setup_recovery_installed?
    Organization.exists? && User.exists?
  end

  def session_inactive_too_long?(session)
    session.last_seen_at.present? && session.last_seen_at < SESSION_INACTIVITY_LIMIT.ago
  end

  def touch_session_if_needed(session)
    return if session.last_seen_at.present? && session.last_seen_at > SESSION_TOUCH_INTERVAL.ago

    current_time = Time.current
    session.update_columns(last_seen_at: current_time, updated_at: current_time)
  end

  def clear_session_cookie
    cookies.delete(:session_id)
    Current.session = nil
  end
end
