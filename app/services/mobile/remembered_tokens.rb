module Mobile
  class RememberedTokens
    Result = Data.define(:body, :status)
    EXCHANGE_ID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

    def initialize(client:, params:)
      @client = client
      @params = params
      @exchange_id = params[:exchange_id].to_s.downcase
    end

    def authorization_code(grant)
      return failure("invalid_exchange_id", oauth: "invalid_request") unless valid_exchange_id?
      return failure("invalid_authorization_code") unless valid_code_binding?(grant)
      session = RememberedSession.find_by(id: grant.remembered_session_id, user_id: grant.resource_owner_id, application_id: @client.id)
      return failure("invalid_authorization_code") unless session

      with_authority(session) do
        previous = session.token_exchanges.find_by(authorization_grant_id: grant.id)
        if previous
          recover_or_revoke(session, previous, reason: "authorization_code_reused")
        elsif session.token_exchanges.exists?(exchange_id: @exchange_id)
          failure("invalid_exchange_id", oauth: "invalid_request")
        elsif !grant.reload.accessible?
          failure("invalid_authorization_code")
        else
          response = yield
          if response.is_a?(Doorkeeper::OAuth::TokenResponse)
            issue_response(session, response.token, authorization_grant: grant)
          else
            failure("invalid_authorization_code")
          end
        end
      end
    end

    def refresh
      return failure("invalid_exchange_id", oauth: "invalid_request") unless valid_exchange_id?
      credential = RefreshCredential.find_by_secret(@params[:refresh_token])
      return failure("invalid_refresh_token") unless credential && credential.remembered_session.application_id == @client.id

      session = credential.remembered_session
      with_authority(session) do
        if credential.reload.consumed_at
          recover_or_revoke(session, credential.token_exchange, reason: "refresh_reuse_detected")
        elsif session.token_exchanges.exists?(exchange_id: @exchange_id)
          failure("invalid_exchange_id", oauth: "invalid_request")
        else
          credential.update!(consumed_at: Time.current)
          token = Doorkeeper::AccessToken.create!(application: @client, resource_owner_id: session.user_id,
            remembered_session_id: session.id, scopes: "buddy_check", expires_in: access_lifetime(session))
          issue_response(session, token, refresh_credential: credential)
        end
      end
    end

    private

    def valid_exchange_id?
      @params[:exchange_id].is_a?(String) && EXCHANGE_ID.match?(@params[:exchange_id])
    end

    def valid_code_binding?(grant)
      verifier = @params[:code_verifier]
      grant && grant.application_id == @client.id && grant.redirect_uri == @client.redirect_uri &&
        @params[:redirect_uri] == grant.redirect_uri && grant.code_challenge_method == "S256" &&
        verifier.is_a?(String) && verifier.match?(/\A[A-Za-z0-9._~-]{43,128}\z/) &&
        ActiveSupport::SecurityUtils.secure_compare(grant.code_challenge,
          Doorkeeper::AccessGrant.generate_code_challenge(verifier))
    end

    def with_authority(session)
      user = User.find_by(id: session.user_id)
      return failure("account_unavailable") unless user
      user.with_lock do
        session.with_lock do
          if !user.mobile_buddy_checks_access?
            session.revoke!(reason: "account_unavailable")
            failure("account_unavailable")
          elsif (code = session.authentication_error)
            failure(code)
          elsif access_lifetime(session) < 1
            failure("remembered_session_expired")
          else
            yield
          end
        end
      end
    end

    def recover_or_revoke(session, exchange, reason:)
      body = exchange&.recover(exchange_id: @exchange_id, request_digest: request_digest)
      if body
        Result.new(body: body, status: :ok)
      else
        session.revoke!(reason: reason)
        failure(reason == "refresh_reuse_detected" ? reason : "revoked_session")
      end
    end

    def issue_response(session, token, **source)
      lifetime = access_lifetime(session)
      token.update!(expires_in: lifetime) if token.expires_in > lifetime
      credential, secret = RefreshCredential.issue!(session)
      body = Doorkeeper::OAuth::TokenResponse.new(token).body.merge(session.identity).merge(
        "refresh_token" => secret, "issuer" => BuddyChecks::Configuration.issuer,
        "installation_id" => session.organization_id, "user_id" => session.user_id, "session_id" => token.id,
        "expires_at" => (token.created_at + token.expires_in).utc.iso8601(6))
      exchange = session.token_exchanges.create!(**source, issued_refresh_credential: credential, access_token: token,
        exchange_id: @exchange_id, request_digest: request_digest, recoverable_until: Time.current + TokenExchange::RECOVERY_SECONDS)
      exchange.save_response!(body)
      Result.new(body: body, status: :ok)
    end

    def access_lifetime(session)
      [ 900, (session.expires_at - Time.current).floor ].min
    end

    def request_digest
      fields = %i[grant_type client_id code redirect_uri code_verifier refresh_token]
      Digest::SHA256.hexdigest(fields.map { |field| @params[field] }.to_json)
    end

    def failure(code, oauth: "invalid_grant")
      Result.new(body: { error: oauth, error_code: code }, status: :bad_request)
    end
  end
end
