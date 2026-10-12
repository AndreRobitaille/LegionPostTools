Doorkeeper.configure do
  orm :active_record
  base_controller "ApplicationController"
  resource_owner_authenticator do
    if current_user && current_user.disabled_at.nil?
      current_user
    else
      if request.get?
        fields = %i[client_id response_type redirect_uri scope state code_challenge code_challenge_method remember_session]
        session[:mobile_authorization_return_to] = "/oauth/authorize?#{params.permit(*fields).to_query}"
      end
      redirect_to new_session_path
      nil
    end
  end
  grant_flows %w[authorization_code]
  default_scopes :buddy_check
  enforce_configured_scopes
  force_pkce
  hash_token_secrets
  custom_access_token_attributes [ :remembered_session_id ]
  access_token_expires_in 15.minutes
  authorize_resource_owner_for_client do |client, owner|
    BuddyChecks::Configuration.client?(client) && owner.mobile_buddy_checks_access?
  end
end
