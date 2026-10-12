module Mobile
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    prepend_before_action :validate_mobile_request
    layout "application"
    helper_method :remember_requested?

    def create
      current_resource_owner.with_lock { super }
    end

    private

    def remember_requested?
      params[:remember_session] == "180_days"
    end

    def pre_auth_params
      super.except(:remembered_session_id)
    end

    def before_successful_authorization(context = nil)
      super
      return unless remember_requested?
      authorized_at = Time.current
      connection = RememberedSession.create!(public_id: SecureRandom.uuid, user: current_resource_owner,
        organization: Organization.first!, application: pre_auth.client.application, authorized_at: authorized_at,
        expires_at: authorized_at + RememberedSession::MAX_LIFETIME)
      pre_auth.custom_access_token_attributes[:remembered_session_id] = connection.id
    end

    def validate_mobile_request
      response.headers["Cache-Control"] = "no-store"
      # Hide authorization paths/queries without making the browser's POST Origin null.
      response.headers["Referrer-Policy"] = "strict-origin"
      client = Doorkeeper::Application.find_by(uid: params[:client_id])
      valid = BuddyChecks::Configuration.enabled? && BuddyChecks::Configuration.origin?(request) &&
        BuddyChecks::Configuration.client?(client) && client.redirect_uri == params[:redirect_uri] &&
        params[:response_type] == "code" && params[:scope].to_s.in?([ "", "buddy_check" ]) &&
        params[:state].to_s.length.between?(32, 512) && params[:response_mode].blank? &&
        params[:remember_session].to_s.in?([ "", "180_days" ]) &&
        params[:code_challenge_method] == "S256" && params[:code_challenge].to_s.match?(/\A[A-Za-z0-9_-]{43}\z/)
      render plain: "Mobile sign-in is unavailable or the authorization request is invalid.", status: :bad_request unless valid
    end
  end
end
