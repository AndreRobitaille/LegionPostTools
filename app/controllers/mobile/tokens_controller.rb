module Mobile
  class TokensController < Doorkeeper::TokensController
    before_action :validate_mobile_request

    def introspect
      head :not_found
    end

    private

    def validate_mobile_request
      response.headers["Cache-Control"] = "no-store"
      return render(json: { error: "temporarily_unavailable" }, status: :service_unavailable) unless
        BuddyChecks::Configuration.enabled? && BuddyChecks::Configuration.origin?(request)
      client = Doorkeeper::Application.find_by(uid: params[:client_id])
      return render(json: { error: "invalid_client" }, status: :unauthorized) unless BuddyChecks::Configuration.client?(client)
      return if action_name == "revoke"

      grant = Doorkeeper::AccessGrant.by_token(params[:code].to_s)
      owner = User.find_by(id: grant&.resource_owner_id)
      valid = params[:grant_type] == "authorization_code" && grant &&
        params[:redirect_uri] == grant.redirect_uri && grant.redirect_uri == client.redirect_uri &&
        owner&.mobile_buddy_checks_access? &&
        params[:code_verifier].to_s.match?(/\A[A-Za-z0-9._~-]{43,128}\z/)
      render json: { error: "invalid_grant" }, status: :bad_request unless valid
    end
  end
end
