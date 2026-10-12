module Mobile
  class TokensController < Doorkeeper::TokensController
    before_action :validate_mobile_request

    def create
      if params[:grant_type] == "refresh_token"
        render_renewal remembered_tokens.refresh
      elsif @grant&.remembered_session_id
        render_renewal remembered_tokens.authorization_code(@grant) { authorize_response }
      else
        super
      end
    end

    def revoke
      credential = RefreshCredential.find_by_secret(params[:token])
      access_token = Doorkeeper::AccessToken.by_token(params[:token].to_s)
      connection_id = credential&.remembered_session_id || access_token&.remembered_session_id
      connection = RememberedSession.find_by(id: connection_id, application_id: @client.id) if connection_id
      if connection
        connection.revoke!
        render json: {}, status: :ok
      else
        super
      end
    end

    def introspect
      head :not_found
    end

    private

    def remembered_tokens
      RememberedTokens.new(client: @client, params: params)
    end

    def render_renewal(result)
      response.headers["Pragma"] = "no-cache"
      render json: result.body, status: result.status
    end

    def validate_mobile_request
      response.headers["Cache-Control"] = "no-store"
      return render(json: { error: "temporarily_unavailable", error_code: "unavailable" }, status: :service_unavailable) unless
        BuddyChecks::Configuration.origin?(request) && (action_name == "revoke" || BuddyChecks::Configuration.enabled?)
      @client = Doorkeeper::Application.find_by(uid: params[:client_id]) if params[:client_id].is_a?(String)
      return render(json: { error: "invalid_client", error_code: "invalid_client" }, status: :unauthorized) unless BuddyChecks::Configuration.client?(@client)
      return if action_name == "revoke"
      return if params[:grant_type] == "refresh_token"

      @grant = Doorkeeper::AccessGrant.by_token(params[:code].to_s)
      return if params[:grant_type] == "authorization_code" && @grant&.remembered_session_id
      owner = User.find_by(id: @grant&.resource_owner_id)
      valid = params[:grant_type] == "authorization_code" && @grant &&
        params[:redirect_uri] == @grant.redirect_uri && @grant.redirect_uri == @client.redirect_uri &&
        owner&.mobile_buddy_checks_access? &&
        params[:code_verifier].to_s.match?(/\A[A-Za-z0-9._~-]{43,128}\z/)
      render json: { error: "invalid_grant", error_code: "invalid_authorization_code" }, status: :bad_request unless valid
    end
  end
end
