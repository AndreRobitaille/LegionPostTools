class Session < ApplicationRecord
  RECENT_AUTHENTICATION_WINDOW = 10.minutes

  belongs_to :user
  has_many :magic_links, dependent: :nullify

  def recently_authenticated?
    authenticated_at.present? && authenticated_at >= RECENT_AUTHENTICATION_WINDOW.ago
  end

  def reauthenticate!
    update!(authenticated_at: Time.current)
  end
end
