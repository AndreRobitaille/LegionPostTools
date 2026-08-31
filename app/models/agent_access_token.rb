class AgentAccessToken < ApplicationRecord
  TOKEN_PREFIX = "lpt"
  LAST_USED_WRITE_INTERVAL = 15.minutes
  PUBLIC_ID_BYTES = 12
  SECRET_BYTES = 32

  belongs_to :user
  belongs_to :revoked_by, class_name: "User", optional: true
  has_many :agent_api_executions, dependent: :destroy
  has_many :official_action_confirmations, dependent: :restrict_with_exception

  validates :public_id, :secret_digest, :display_hint, :name, :expires_at, presence: true
  validates :public_id, uniqueness: true
  validates :name, length: { maximum: 80 }

  scope :newest_first, -> { order(created_at: :desc) }

  def self.issue!(user:, name:, expires_in:)
    public_id = SecureRandom.hex(PUBLIC_ID_BYTES)
    secret = SecureRandom.hex(SECRET_BYTES)
    plaintext = [ TOKEN_PREFIX, public_id, secret ].join("_")
    token = create!(
      user: user,
      public_id: public_id,
      secret_digest: digest(secret),
      display_hint: secret.last(4),
      name: name.to_s.strip,
      expires_at: expires_in.from_now
    )
    [ token, plaintext ]
  end

  def self.authenticate(plaintext)
    public_id, secret = parse(plaintext)
    candidate_digest = digest(secret || SecureRandom.hex(SECRET_BYTES))
    token = find_by(public_id: public_id) if public_id
    stored_digest = token&.secret_digest || digest(SecureRandom.hex(SECRET_BYTES))
    valid_secret = ActiveSupport::SecurityUtils.secure_compare(stored_digest, candidate_digest)
    return nil unless token && valid_secret && token.active?

    token.touch_last_used_if_needed
    token
  end

  def self.digest(value)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, value.to_s)
  end

  def active?
    revoked_at.blank? && expires_at.future? && user.disabled_at.blank?
  end

  def revoked?
    revoked_at.present?
  end

  def expired?
    expires_at.past?
  end

  def revoke!(actor)
    update!(revoked_at: Time.current, revoked_by: actor)
  end

  def touch_last_used_if_needed
    return if last_used_at.present? && last_used_at >= LAST_USED_WRITE_INTERVAL.ago

    update_columns(last_used_at: Time.current, updated_at: Time.current)
  end

  def self.parse(plaintext)
    match = plaintext.to_s.match(/\A#{TOKEN_PREFIX}_([0-9a-f]{24})_([0-9a-f]{64})\z/)
    match ? [ match[1], match[2] ] : [ nil, nil ]
  end
  private_class_method :parse
end
