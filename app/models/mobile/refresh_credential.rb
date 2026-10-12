module Mobile
  class RefreshCredential < ApplicationRecord
    belongs_to :remembered_session, class_name: "Mobile::RememberedSession"
    has_one :token_exchange, class_name: "Mobile::TokenExchange", dependent: :restrict_with_exception

    def self.find_by_secret(secret)
      return unless secret.is_a?(String) && secret.match?(/\Abrt_[A-Za-z0-9_-]{64}\z/)
      find_by(token_digest: Digest::SHA256.hexdigest(secret))
    end

    def self.issue!(remembered_session)
      secret = "brt_#{SecureRandom.urlsafe_base64(48)}"
      [ create!(remembered_session: remembered_session, token_digest: Digest::SHA256.hexdigest(secret)), secret ]
    end
  end
end
