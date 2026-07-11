class User < ApplicationRecord
  belongs_to :person
  has_many :permission_grants, dependent: :destroy
  has_many :passkey_credentials, dependent: :destroy

  normalizes :email_address, with: ->(value) { value.strip.downcase }

  before_validation :assign_webauthn_id, on: :create

  validates :email_address, presence: true, uniqueness: true
  validates :person_id, uniqueness: true
  validates :webauthn_id, presence: true, uniqueness: true

  def can?(capability)
    permission_grants.exists?(capability: capability.to_s)
  end

  private

  # WebAuthn requires an opaque, non-PII, base64url user handle (not the DB id).
  def assign_webauthn_id
    self.webauthn_id ||= WebAuthn.generate_user_id
  end
end
