class WebsiteAccessToken < ApplicationRecord
  TOKEN_PREFIX = "lptw"
  LAST_USED_WRITE_INTERVAL = 15.minutes

  belongs_to :organization
  belongs_to :created_by, class_name: "User"
  belongs_to :revoked_by, class_name: "User", optional: true

  normalizes :name, with: ->(name) { name.strip }
  validates :name, :public_id, :secret_digest, :display_hint, presence: true
  validates :name, length: { maximum: 80 }
  validates :public_id, uniqueness: true

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def self.issue!(organization:, actor:, name:)
    public_id = SecureRandom.hex(12)
    secret = SecureRandom.hex(32)
    token = create!(organization: organization, created_by: actor, name: name,
      public_id: public_id, secret_digest: digest(secret), display_hint: secret.last(4))
    [ token, "#{TOKEN_PREFIX}_#{public_id}_#{secret}" ]
  end

  def self.authenticate(plaintext)
    match = plaintext.to_s.match(/\A#{TOKEN_PREFIX}_([0-9a-f]{24})_([0-9a-f]{64})\z/)
    return unless match

    token = find_by(public_id: match[1])
    return unless token && ActiveSupport::SecurityUtils.secure_compare(token.secret_digest, digest(match[2]))
    return if token.revoked?

    if token.last_used_at.nil? || token.last_used_at < LAST_USED_WRITE_INTERVAL.ago
      token.update_columns(last_used_at: Time.current)
    end
    token
  end

  def self.digest(secret)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, secret)
  end
  private_class_method :digest

  def revoked?
    revoked_at.present?
  end

  def revoke!(actor)
    with_lock do
      update!(revoked_at: Time.current, revoked_by: actor) unless revoked?
    end
  end
end
