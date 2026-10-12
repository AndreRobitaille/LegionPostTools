module Mobile
  class RememberedSession < ApplicationRecord
    MAX_LIFETIME = 180 * 24 * 60 * 60

    belongs_to :user
    belongs_to :organization
    belongs_to :application, class_name: "Doorkeeper::Application"
    has_many :refresh_credentials, class_name: "Mobile::RefreshCredential", dependent: :restrict_with_exception
    has_many :token_exchanges, class_name: "Mobile::TokenExchange", dependent: :restrict_with_exception
    has_many :access_tokens, class_name: "Doorkeeper::AccessToken", dependent: :restrict_with_exception

    attr_readonly :public_id, :user_id, :organization_id, :application_id, :authorized_at, :expires_at
    validates :public_id, :authorized_at, :expires_at, presence: true

    def authentication_error
      if revoked_at
        revocation_reason == "refresh_reuse_detected" ? "refresh_reuse_detected" : "revoked_session"
      elsif expires_at <= Time.current
        "remembered_session_expired"
      end
    end

    def revoke!(reason: "user_revoked")
      with_lock do
        update!(revoked_at: Time.current, revocation_reason: reason) unless revoked_at
        access_tokens.where(revoked_at: nil).update_all(revoked_at: revoked_at)
        token_exchanges.where.not(response_ciphertext: nil).update_all(response_ciphertext: nil)
      end
    end

    def identity
      { "remembered_session_id" => public_id, "authorized_at" => authorized_at.utc.iso8601(6),
        "remembered_until" => expires_at.utc.iso8601(6) }
    end
  end
end
