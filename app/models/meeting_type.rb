class MeetingType < ApplicationRecord
  belongs_to :organization
  has_many :meetings, dependent: :restrict_with_exception
  has_many :meeting_type_agenda_items, dependent: :destroy
  has_many :meeting_type_agenda_sections, -> { ordered }, dependent: :destroy
  has_many :dated_agendas, dependent: :restrict_with_exception
  has_many :meeting_minutes,
    class_name: "MeetingMinutes",
    dependent: :restrict_with_exception,
    inverse_of: :meeting_type

  include Reorderable

  normalizes :slug, with: ->(value) { value.to_s.strip.downcase }
  before_validation :normalize_optional_fields
  before_validation :ensure_slug
  after_create :create_default_agenda_section!

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

  def default_agenda_section
    meeting_type_agenda_sections.ordered.first
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

  def create_default_agenda_section!
    meeting_type_agenda_sections.create!(title: "Order of Business", position: 1)
  end
end
