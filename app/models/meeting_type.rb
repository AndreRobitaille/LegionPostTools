class MeetingType < ApplicationRecord
  belongs_to :organization
  has_many :meeting_type_agenda_items, dependent: :destroy

  include Reorderable

  normalizes :slug, with: ->(value) { value.to_s.strip.downcase }
  before_validation :normalize_optional_fields
  before_validation :ensure_slug

  validates :name, :slug, presence: true
  validates :name, uniqueness: { scope: :organization_id }
  validates :slug, uniqueness: { scope: :organization_id }
  validates :source_key, uniqueness: { scope: :organization_id }, allow_blank: true
  validates :position, numericality: { only_integer: true }
  validates :position, uniqueness: { scope: :organization_id }

  scope :ordered, -> { order(:position, :name) }
  scope :active, -> { where(active: true) }

  def self.reorder!(organization, ordered_ids)
    reorder_within!(organization.meeting_types, ordered_ids)
  end

  def seeded?
    source_key.present?
  end

  private

  def normalize_optional_fields
    self.source_key = source_key&.strip.presence
  end

  def ensure_slug
    return if slug.present?

    base = name.to_s.parameterize
    return if base.blank?

    candidate = base
    suffix = 2
    scope = organization&.meeting_types&.where&.not(id: id)
    while scope&.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end
end
