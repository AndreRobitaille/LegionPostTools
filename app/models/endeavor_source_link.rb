class EndeavorSourceLink < ApplicationRecord
  include ImmutableEndeavorHistory
  belongs_to :endeavor
  belongs_to :endeavor_history_edition
  belongs_to :minutes_revision
  validates :record_key, :source_ids, presence: true
  validate do
    if endeavor_history_edition&.endeavor_id != endeavor_id || minutes_revision&.meeting_minutes&.organization_id != endeavor&.organization_id
      errors.add(:base, "Evidence must belong to the same Endeavor and organization")
    end
    if minutes_revision && record_key.present?
      item = EndeavorHistory::SourceDocument.new(minutes_revision).items.find { |entry| entry["key"] == record_key }
      allowed = item&.fetch("units", [])&.map { |unit| unit["id"] } || []
      errors.add(:source_ids, "must resolve to this revision item") unless source_ids.is_a?(Array) && source_ids.any? && (source_ids - allowed).empty?
    end
  end
end
