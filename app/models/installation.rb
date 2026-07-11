class Installation < ApplicationRecord
  SINGLETON_KEY = "primary".freeze

  validates :singleton_key, presence: true, uniqueness: true

  def self.singleton
    find_or_create_by!(singleton_key: SINGLETON_KEY)
  end

  def self.setup_completed?
    singleton.setup_completed_at.present?
  end
end
