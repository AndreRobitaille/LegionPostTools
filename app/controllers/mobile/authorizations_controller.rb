module Mobile
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    prepend_before_action :validate_mobile_request
    layout "application"

    private

    def validate_mobile_request
      response.headers["Cache-Control"] = "no-store"
      # Hide authorization paths/queries without making the browser's POST Origin null.
      response.headers["Referrer-Policy"] = "strict-origin"
      client = Doorkeeper::Application.find_by(uid: params[:client_id])
      valid = BuddyChecks::Configuration.enabled? && BuddyChecks::Configuration.origin?(request) &&
        BuddyChecks::Configuration.client?(client) && client.redirect_uri == params[:redirect_uri] &&
        params[:response_type] == "code" && params[:scope].to_s.in?([ "", "buddy_check" ]) &&
        params[:state].to_s.length.between?(32, 512) && params[:response_mode].blank? &&
        params[:code_challenge_method] == "S256" && params[:code_challenge].to_s.match?(/\A[A-Za-z0-9_-]{43}\z/)
      render plain: "Mobile sign-in is unavailable or the authorization request is invalid.", status: :bad_request unless valid
    end
  end
end
