module Mobile
  class TokenExchange < ApplicationRecord
    RECOVERY_SECONDS = 120

    belongs_to :remembered_session, class_name: "Mobile::RememberedSession"
    belongs_to :authorization_grant, class_name: "Doorkeeper::AccessGrant", optional: true
    belongs_to :refresh_credential, class_name: "Mobile::RefreshCredential", optional: true
    belongs_to :issued_refresh_credential, class_name: "Mobile::RefreshCredential"
    belongs_to :access_token, class_name: "Doorkeeper::AccessToken"

    def save_response!(body)
      update!(response_ciphertext: encryptor.encrypt_and_sign(body, purpose: purpose, expires_at: recoverable_until))
    end

    def recover(exchange_id:, request_digest:)
      return unless self.exchange_id == exchange_id && self.request_digest == request_digest &&
        recoverable_until > Time.current && issued_refresh_credential.reload.consumed_at.nil? &&
        !access_token.reload.revoked? && response_ciphertext
      body = encryptor.decrypt_and_verify(response_ciphertext, purpose: purpose)
      return unless body
      body.merge("expires_in" => [ (Time.iso8601(body.fetch("expires_at")) - Time.current).floor, 0 ].max)
    rescue ActiveSupport::MessageEncryptor::InvalidMessage
      nil
    end

    private

    def purpose
      "mobile-token-exchange:#{id}"
    end

    def encryptor
      key = Rails.application.key_generator.generate_key("mobile-token-exchange-recovery-v1", 32)
      ActiveSupport::MessageEncryptor.new(key, cipher: "aes-256-gcm", serializer: JSON)
    end
  end
end
