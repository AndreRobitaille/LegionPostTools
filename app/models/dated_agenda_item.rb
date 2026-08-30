class DatedAgendaItem < ApplicationRecord
  include Reorderable

  belongs_to :dated_agenda
  belongs_to :agenda_section,
    class_name: "DatedAgendaSection",
    foreign_key: :dated_agenda_section_id,
    inverse_of: :agenda_items
  belongs_to :meeting_type_agenda_item, optional: true
  belongs_to :agenda_item_catalog_entry, optional: true
  belongs_to :endeavor, optional: true
  has_many :roll_call_entries,
    -> { order(:position) },
    class_name: "DatedAgendaRollCallEntry",
    inverse_of: :dated_agenda_item,
    dependent: :destroy

  has_rich_text :body
  has_rich_text :commander_notes

  before_validation :normalize_optional_fields
  before_validation :assign_default_agenda_section
  validate :catalog_entry_belongs_to_same_organization
  validate :meeting_type_agenda_item_belongs_to_same_meeting_type
  validate :agenda_section_belongs_to_same_dated_agenda
  validate :endeavor_belongs_to_same_organization
  validate :agenda_is_editable, on: %i[create update]
  before_destroy :prevent_destroy_when_locked
  after_save :sync_roll_call_snapshot

  validates :title, :behavior_type, presence: true
  validates :behavior_type, inclusion: { in: AgendaItemCatalogEntry::BEHAVIOR_TYPES.keys }, allow_blank: true
  validates :position, numericality: { only_integer: true }
  validates :position, uniqueness: { scope: :dated_agenda_section_id }
  validates :agenda_item_catalog_entry_id, uniqueness: { scope: :dated_agenda_id }, allow_nil: true
  validates :endeavor_id, uniqueness: { scope: :dated_agenda_id }, allow_nil: true

  scope :ordered, -> {
    joins(:agenda_section).order("dated_agenda_sections.position", "dated_agenda_items.position", "dated_agenda_items.title")
  }
  scope :active, -> { where(active: true) }

  def self.attributes_from_template_item(template_item, position:, dated_agenda:, agenda_section:)
    {
      dated_agenda: dated_agenda,
      agenda_section: agenda_section,
      meeting_type_agenda_item: template_item,
      agenda_item_catalog_entry: template_item.agenda_item_catalog_entry,
      position: position,
      title: template_item.title,
      summary: template_item.summary,
      behavior_type: template_item.agenda_item_catalog_entry.behavior_type,
      active: template_item.active,
      body: template_item.body.to_s,
      commander_notes: template_item.commander_notes.to_s,
      show_wording_on_agenda: template_item.show_wording_on_agenda,
      show_wording_in_minutes: template_item.show_wording_in_minutes,
      source_key: template_item.source_key,
      source_label: template_item.source_label,
      seeded_at: template_item.seeded_at
    }
  end

  def self.create_from_catalog_entry!(catalog_entry, position:, dated_agenda:, agenda_section: nil, meeting_type_agenda_item: nil)
    attrs = {
      dated_agenda: dated_agenda,
      agenda_section: agenda_section || dated_agenda.default_agenda_section,
      agenda_item_catalog_entry: catalog_entry,
      position: position,
      title: catalog_entry.title,
      summary: catalog_entry.summary,
      behavior_type: catalog_entry.behavior_type,
      active: true,
      body: catalog_entry.body.to_s,
      commander_notes: catalog_entry.commander_notes.to_s,
      show_wording_on_agenda: catalog_entry.show_wording_on_agenda,
      show_wording_in_minutes: catalog_entry.show_wording_in_minutes
    }
    attrs[:meeting_type_agenda_item] = meeting_type_agenda_item if meeting_type_agenda_item
    create!(attrs)
  end

  def self.create_from_endeavor!(endeavor, position:, dated_agenda:, agenda_section: nil)
    create!(
      dated_agenda: dated_agenda,
      agenda_section: agenda_section || dated_agenda.default_agenda_section,
      endeavor: endeavor,
      position: position,
      title: endeavor.title,
      summary: endeavor.summary,
      behavior_type: "business_item",
      active: true,
      body: endeavor.details.to_s
    )
  end

  def self.reorder!(container, ordered_ids)
    agenda_section = container.is_a?(DatedAgendaSection) ? container : container.default_agenda_section
    active_scope = agenda_section.agenda_items.active
    ids = Array(ordered_ids).map(&:to_i)
    records = active_scope.where(id: ids).index_by(&:id)
    active_ids = active_scope.pluck(:id)
    raise ActiveRecord::RecordNotFound unless records.length == ids.length && ids.uniq.length == ids.length && ids.sort == active_ids.sort

    target_positions = active_scope.order(:position).pluck(:position)
    transaction do
      offset = (agenda_section.agenda_items.maximum(:position) || 0) + 1
      ids.each_with_index { |id, index| records.fetch(id).update!(position: offset + index) }
      ids.each_with_index { |id, index| records.fetch(id).update!(position: target_positions[index]) }
    end
  end

  def self.reorder_active_contiguously!(agenda_section, ordered_ids)
    active_scope = agenda_section.agenda_items.active
    ids = Array(ordered_ids).map { |id| Integer(id.to_s, 10) }
    records = active_scope.where(id: ids).index_by(&:id)
    active_ids = active_scope.pluck(:id)
    raise ActiveRecord::RecordNotFound unless records.length == ids.length && ids.uniq.length == ids.length && ids.sort == active_ids.sort

    inactive_records = agenda_section.agenda_items.where(active: false).order(:position, :id).to_a
    ordered_records = ids.map { |id| records.fetch(id) } + inactive_records

    transaction do
      offset = agenda_section.agenda_items.maximum(:position).to_i + ordered_records.length + 1
      ordered_records.each_with_index { |record, index| record.update_columns(position: offset + index) }
      ordered_records.each_with_index { |record, index| record.update_columns(position: index + 1) }
    end
  rescue ArgumentError, TypeError
    raise ActiveRecord::RecordNotFound
  end

  def roll_call?
    behavior_type == "roll_call"
  end

  def refresh_roll_call!
    unless dated_agenda.draft?
      errors.add(:base, "roll call can only be refreshed while the agenda is a draft")
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      roll_call_entries.destroy_all
      create_roll_call_snapshot!
    end
  end

  def replace_roll_call_entries!(entries)
    unless roll_call? && dated_agenda.draft?
      errors.add(:base, "officer list can only be edited on a draft roll-call item")
      raise ActiveRecord::RecordInvalid, self
    end

    if entries.empty?
      errors.add(:base, "officer list must include at least one office")
      raise ActiveRecord::RecordInvalid, self
    end

    transaction do
      roll_call_entries.destroy_all
      entries.each_with_index do |attributes, index|
        roll_call_entries.create!(attributes.merge(position: index + 1))
      end
    end
  end

  private

  def normalize_optional_fields
    self.summary = summary.to_s
    self.source_key = source_key&.strip.presence
  end

  def sync_roll_call_snapshot
    if roll_call?
      create_roll_call_snapshot! if roll_call_entries.empty?
    elsif roll_call_entries.exists?
      roll_call_entries.destroy_all
    end
  end

  def create_roll_call_snapshot!
    meeting_date = dated_agenda.starts_at.in_time_zone.to_date
    position = 0
    titles = dated_agenda.organization.position_titles.where(active: true).order(:display_order, :name).includes(position_assignments: :person)

    titles.each do |title|
      assignments = title.position_assignments
        .select { |assignment| assignment.active_on?(meeting_date) }
        .sort_by { |assignment| [ assignment.person.last_name, assignment.person.first_name, assignment.person_id ] }
      next if assignments.empty? && !title.required_by_default?

      assignments = [ nil ] if assignments.empty?
      assignments.each do |assignment|
        position += 1
        roll_call_entries.create!(
          position_title: title,
          person: assignment&.person,
          office_name: title.name,
          person_name: assignment&.person&.full_name,
          position: position
        )
      end
    end
  end

  def assign_default_agenda_section
    self.agenda_section ||= dated_agenda&.default_agenda_section
  end

  def agenda_is_editable
    return unless DatedAgenda.where(id: dated_agenda_id).pick(:status).in?(%w[approved published])

    errors.add(:base, "agenda is locked")
  end

  def prevent_destroy_when_locked
    return true if destroyed_by_association
    return true unless DatedAgenda.where(id: dated_agenda_id).pick(:status).in?(%w[approved published])

    errors.add(:base, "agenda is locked")
    throw(:abort)
  end

  def catalog_entry_belongs_to_same_organization
    return if dated_agenda.blank? || agenda_item_catalog_entry.blank?
    return if dated_agenda.organization_id == agenda_item_catalog_entry.organization_id

    errors.add(:agenda_item_catalog_entry, "must belong to the same organization")
  end

  def meeting_type_agenda_item_belongs_to_same_meeting_type
    return if meeting_type_agenda_item.blank? || dated_agenda.blank?
    return if meeting_type_agenda_item.meeting_type_id == dated_agenda.meeting_type_id

    errors.add(:meeting_type_agenda_item, "must belong to the same meeting type")
  end

  def agenda_section_belongs_to_same_dated_agenda
    return if agenda_section.blank? || dated_agenda.blank?
    return if agenda_section.dated_agenda_id == dated_agenda_id

    errors.add(:agenda_section, "must belong to the same dated agenda")
  end

  def endeavor_belongs_to_same_organization
    return if dated_agenda.blank? || endeavor.blank?
    return if dated_agenda.organization_id == endeavor.organization_id

    errors.add(:endeavor, "must belong to the same organization")
  end
end
