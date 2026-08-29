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
    "reading_recitation" => "Reading/recitation",
    "roll_call" => "Officer roll call"
  }.freeze

  belongs_to :organization
  has_rich_text :body
  has_rich_text :commander_notes
  has_many :dated_agenda_items, dependent: :restrict_with_exception

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

  def self.reorder!(organization, ordered_ids_by_category)
    category_ids = normalize_category_ids(ordered_ids_by_category)

    transaction do
      records = organization.agenda_item_catalog_entries.lock.index_by(&:id)
      validate_complete_order!(records, category_ids)
      persist_category_order!(records, category_ids)
    end
  end

  def self.move!(organization, entry, direction)
    raise ActiveRecord::RecordNotFound unless direction.in?(%w[up down])

    transaction do
      records = organization.agenda_item_catalog_entries.lock.index_by(&:id)
      record = records[entry.id]
      raise ActiveRecord::RecordNotFound unless record

      category_ids = CATEGORIES.keys.index_with do |category|
        records.values
          .select { |candidate| candidate.category == category }
          .sort_by { |candidate| [ candidate.position, candidate.title, candidate.id ] }
          .map(&:id)
      end
      move_id!(category_ids, record, direction)
      persist_category_order!(records, category_ids)
    end
  end

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

  def self.normalize_category_ids(ordered_ids_by_category)
    supplied = ordered_ids_by_category.to_h.stringify_keys
    raise ActiveRecord::RecordNotFound if (supplied.keys - CATEGORIES.keys).any?

    CATEGORIES.keys.index_with { |category| Array(supplied[category]).map(&:to_i) }
  end

  def self.validate_complete_order!(records, category_ids)
    supplied_ids = category_ids.values.flatten
    expected_ids = records.keys
    valid = supplied_ids.length == supplied_ids.uniq.length && supplied_ids.sort == expected_ids.sort
    raise ActiveRecord::RecordNotFound unless valid
  end

  def self.persist_category_order!(records, category_ids)
    offset = records.values.map(&:position).max.to_i + records.length + 1
    records.values.each_with_index { |record, index| record.update!(position: offset + index) }

    category_ids.each do |category, ids|
      ids.each_with_index do |id, index|
        records.fetch(id).update!(category: category, position: index + 1)
      end
    end
  end

  def self.move_id!(category_ids, record, direction)
    category_index = CATEGORIES.keys.index(record.category)
    ids = category_ids.fetch(record.category)
    item_index = ids.index(record.id)

    if direction == "up"
      if item_index.positive?
        ids[item_index - 1], ids[item_index] = ids[item_index], ids[item_index - 1]
      elsif category_index.positive?
        ids.delete(record.id)
        category_ids.fetch(CATEGORIES.keys[category_index - 1]) << record.id
      else
        raise ActiveRecord::RecordNotFound
      end
    elsif item_index < ids.length - 1
      ids[item_index], ids[item_index + 1] = ids[item_index + 1], ids[item_index]
    elsif category_index < CATEGORIES.length - 1
      ids.delete(record.id)
      category_ids.fetch(CATEGORIES.keys[category_index + 1]).unshift(record.id)
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  private_class_method :normalize_category_ids, :validate_complete_order!, :persist_category_order!, :move_id!

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
