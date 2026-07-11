class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :authenticated?

  before_action :redirect_to_setup_if_needed
  before_action :resume_session

  def current_user
    Current.session&.user
  end

  def authenticated?
    current_user.present?
  end

  def require_authentication
    return if authenticated?

    redirect_to new_session_path, alert: "You must sign in first."
  end

  def start_new_session_for(user)
    session = Session.create!(user: user, ip_address: request.remote_ip, user_agent: request.user_agent, last_seen_at: Time.current)
    cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
    Current.session = session
  end

  def terminate_current_session
    Current.session&.destroy!
    Current.session = nil
    cookies.delete(:session_id)
  end

  def redirect_to_setup_if_needed
    return if controller_name == "setup"
    return if Organization.exists? || User.exists?

    redirect_to new_setup_path
  end

  def resume_session
    return if Current.session.present?

    session_id = cookies.signed[:session_id]
    Current.session = Session.find_by(id: session_id) if session_id.present?
  end
end
