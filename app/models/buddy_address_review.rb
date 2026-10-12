class BuddyAddressReview < ApplicationRecord
  include ImmutableMembershipEntry
  FIELDS = %w[street city state postal_code country].freeze
  belongs_to :person
  belongs_to :reviewed_by, class_name: "User"
  validates :source_digest, :source_note, presence: true
  validates :source_note, length: { maximum: 1000 }
  validate :reviewed_components

  def self.source_digest(person)
    address, imported_at, version = Person.where(id: person.id).pick(:roster_address, :roster_imported_at, :buddy_address_source_version)
    Digest::SHA256.hexdigest(JSON.generate([ address, imported_at&.iso8601(6), version ]))
  end

  def current_source?
    source_digest == self.class.source_digest(person)
  end

  private

  def reviewed_components
    unless components.is_a?(Hash) && (components.keys - FIELDS).empty? &&
        components.values.all? { |value| value.is_a?(String) && value.length <= 200 }
      errors.add(:components, "must contain only reviewed postal fields")
    end
  end
end
