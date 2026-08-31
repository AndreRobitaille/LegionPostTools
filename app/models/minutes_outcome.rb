class MinutesOutcome < ApplicationRecord
  include Reorderable

  KINDS = %w[motion decision].freeze
  DISPOSITIONS = %w[adopted lost withdrawn postponed referred no_vote not_recorded].freeze

  belongs_to :minutes_item, inverse_of: :outcomes
  belongs_to :mover_person, class_name: "Person", optional: true
  belongs_to :seconder_person, class_name: "Person", optional: true

  normalizes :text, with: ->(value) { value.to_s.strip }
  normalizes :mover_name, :seconder_name, :vote_summary,
    with: ->(value) { value.to_s.strip.presence }

  validates :kind, :text, :disposition, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :disposition, inclusion: { in: DISPOSITIONS }
  validates :position,
    numericality: { only_integer: true, greater_than: 0 },
    uniqueness: { scope: :minutes_item_id }

  before_validation :snapshot_participant_names

  def self.reorder!(minutes_item, ordered_ids)
    reorder_within!(minutes_item.outcomes, ordered_ids)
  end

  private

  def snapshot_participant_names
    self.mover_name = mover_person&.full_name if will_save_change_to_mover_person_id?
    self.seconder_name = seconder_person&.full_name if will_save_change_to_seconder_person_id?
  end
end
