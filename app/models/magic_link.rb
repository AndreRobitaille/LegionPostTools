class MagicLink < ApplicationRecord
  TOKEN_TTL = 15.minutes

  belongs_to :user

  attr_reader :token

  validates :token_digest, :expires_at, presence: true

  def self.create_for!(user)
    token = SecureRandom.urlsafe_base64(32)
    create!(user: user, token_digest: digest(token), expires_at: TOKEN_TTL.from_now).tap do |magic_link|
      magic_link.instance_variable_set(:@token, token)
    end
  end

  def self.consume!(token)
    return nil if token.blank?

    transaction do
      magic_link = lock.find_by(token_digest: digest(token))
      return nil if magic_link.blank? || magic_link.used_at.present? || magic_link.expires_at.past?

      user = magic_link.user
      return nil if user.disabled_at.present?

      magic_link.update!(used_at: Time.current)
      user.update!(email_verified_at: Time.current) if user.email_verified_at.blank?
      user
    end
  end

  def self.digest(token)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, token)
  end
end
