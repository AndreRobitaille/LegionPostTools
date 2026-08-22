class MagicLink < ApplicationRecord
  TOKEN_TTL = 15.minutes
  MAX_FAILED_ATTEMPTS = 5
  PURPOSES = %w[sign_in create_agent_access_token].freeze

  belongs_to :user
  belongs_to :session, optional: true

  attr_reader :token, :login_code, :browser_challenge

  validates :token_digest, :expires_at, :purpose, presence: true
  validates :purpose, inclusion: { in: PURPOSES }
  validates :code_digest, :browser_challenge_digest, presence: true, on: :create
  validates :session, presence: true, if: :reauthentication?
  validate :session_belongs_to_user

  def self.create_for!(user, purpose: "sign_in", session: nil)
    token = SecureRandom.urlsafe_base64(32)
    login_code = format("%08d", SecureRandom.random_number(100_000_000))
    browser_challenge = SecureRandom.urlsafe_base64(32)
    create!(
      user: user,
      session: session,
      purpose: purpose,
      token_digest: digest(token),
      code_digest: digest(login_code),
      browser_challenge_digest: digest(browser_challenge),
      expires_at: TOKEN_TTL.from_now
    ).tap do |magic_link|
      magic_link.instance_variable_set(:@token, token)
      magic_link.instance_variable_set(:@login_code, login_code)
      magic_link.instance_variable_set(:@browser_challenge, browser_challenge)
    end
  end

  def self.consume!(token, purpose: "sign_in", session: nil)
    return nil if token.blank? || PURPOSES.exclude?(purpose)

    transaction do
      challenge = lock.find_by(token_digest: digest(token), purpose: purpose)
      consume_challenge(challenge, session: session)
    end
  end

  def self.consume_code!(browser_challenge:, code:, purpose: "sign_in", session: nil)
    normalized_code = normalize_code(code)
    return nil if browser_challenge.blank? || normalized_code.blank?

    transaction do
      challenge = lock.find_by(browser_challenge_digest: digest(browser_challenge), purpose: purpose)
      return nil unless usable?(challenge, session: session)

      unless secure_match?(challenge.code_digest, digest(normalized_code))
        challenge.increment!(:failed_attempts)
        return nil
      end

      consume_challenge(challenge, session: session)
    end
  end

  def self.normalize_code(value)
    match = value.to_s.strip.match(/\A(\d{4})[ -]?(\d{4})\z/)
    match ? "#{match[1]}#{match[2]}" : nil
  end

  def self.format_code(value)
    normalized = normalize_code(value)
    normalized ? "#{normalized.first(4)} #{normalized.last(4)}" : nil
  end

  def self.digest(value)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, value.to_s)
  end

  def reauthentication?
    purpose == "create_agent_access_token"
  end

  class << self
    private

    def consume_challenge(challenge, session: nil)
      return nil unless usable?(challenge, session: session)

      challenge.update!(used_at: Time.current)
      challenge.user.update!(email_verified_at: Time.current) if challenge.user.email_verified_at.blank?
      challenge.user
    end

    def usable?(challenge, session: nil)
      return false if challenge.blank?
      return false if challenge.used_at.present? || challenge.expires_at.past?
      return false if challenge.failed_attempts >= MAX_FAILED_ATTEMPTS
      return false if challenge.user.disabled_at.present?
      return false if challenge.reauthentication? && challenge.session != session

      true
    end

    def secure_match?(stored, candidate)
      stored.present? && ActiveSupport::SecurityUtils.secure_compare(stored, candidate)
    end
  end

  private

  def session_belongs_to_user
    return if session.blank? || session.user == user

    errors.add(:session, "must belong to the same user")
  end
end
