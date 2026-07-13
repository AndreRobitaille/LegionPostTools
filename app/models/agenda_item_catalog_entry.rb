class AgendaItemCatalogEntry < ApplicationRecord
  CATEGORIES = {
    "ceremony" => "Ceremony",
    "business" => "Business",
    "reports" => "Reports",
    "membership" => "Membership",
    "memorial" => "Memorial",
    "administration" => "Administration"
  }.freeze

  BEHAVIOR_TYPES = {
    "scripted_ceremony" => "Scripted ceremony",
    "section_heading" => "Section heading",
    "report_slot" => "Report slot",
    "business_item" => "Business item",
    "motion_vote_item" => "Motion/vote item",
    "reading_recitation" => "Reading/recitation"
  }.freeze

  belongs_to :organization
  has_rich_text :body

  normalizes :slug, with: ->(value) { value.to_s.strip.downcase }
  before_validation :normalize_optional_fields
  before_validation :ensure_slug

  validates :title, :slug, :category, :behavior_type, presence: true
  validates :category, inclusion: { in: CATEGORIES.keys }
  validates :behavior_type, inclusion: { in: BEHAVIOR_TYPES.keys }
  validates :slug, uniqueness: { scope: :organization_id }
  validates :source_key, uniqueness: { scope: :organization_id }, allow_blank: true
  validates :position, numericality: { only_integer: true }

  scope :ordered, -> { order(:category, :position, :title) }
  scope :active, -> { where(active: true) }

  def category_label
    CATEGORIES.fetch(category)
  end

  def behavior_type_label
    BEHAVIOR_TYPES.fetch(behavior_type)
  end

  def seeded?
    source_key.present?
  end

  private

  def normalize_optional_fields
    self.summary = summary.to_s
    self.source_key = source_key&.strip.presence
  end

  # Slug is a stable internal identifier, never shown to officers. Derive it from
  # the title so the edit form doesn't have to expose it, keeping it unique per post.
  def ensure_slug
    return if slug.present?

    base = title.to_s.parameterize
    return if base.blank?

    candidate = base
    suffix = 2
    scope = organization&.agenda_item_catalog_entries&.where&.not(id: id)
    while scope&.exists?(slug: candidate)
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end
    self.slug = candidate
  end
end
