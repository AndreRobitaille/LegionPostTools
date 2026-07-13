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

  validates :title, :slug, :category, :behavior_type, presence: true
  validates :summary, presence: true, allow_blank: true
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
end
