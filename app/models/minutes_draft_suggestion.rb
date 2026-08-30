class MinutesDraftSuggestion < ApplicationRecord
  KINDS = %w[item_summary outcome attendance additional_item].freeze
  CONFIDENCES = %w[high medium low].freeze
  REVIEW_STATES = %w[unreviewed used edited discarded].freeze

  belongs_to :minutes_draft_run, inverse_of: :suggestions
  belongs_to :minutes_item, optional: true
  belongs_to :minutes_attendance_entry, optional: true
  belongs_to :minutes_section, optional: true
  belongs_to :source_dated_agenda_item, class_name: "DatedAgendaItem", optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :confidence, inclusion: { in: CONFIDENCES }
  validates :review_state, inclusion: { in: REVIEW_STATES }
  validates :source_start_line,
    numericality: { only_integer: true, greater_than: 0 }
  validates :source_end_line,
    numericality: { only_integer: true, greater_than: 0 }
  validate :source_range_is_valid
  validate :target_matches_kind
  validate :targets_belong_to_minutes
  validate :review_provenance_is_complete

  scope :unreviewed, -> { where(review_state: "unreviewed") }

  def unreviewed? = review_state == "unreviewed"

  def source_excerpt
    return nil unless minutes_draft_run.meeting_transcript.source_available?

    document = MinutesDrafting::SourceDocument.new(minutes_draft_run.meeting_transcript.source_text)
    document.excerpt(source_start_line, source_end_line)
  end

  private

  def source_range_is_valid
    return if minutes_draft_run.blank? || source_start_line.blank? || source_end_line.blank?

    errors.add(:source_end_line, "must follow the first source line") if source_end_line < source_start_line
    if source_end_line > minutes_draft_run.source_line_count
      errors.add(:source_end_line, "must exist in the transcript source")
    end
  end

  def target_matches_kind
    case kind
    when "item_summary", "outcome"
      errors.add(:minutes_item, "is required") if minutes_item.blank?
    when "attendance"
      errors.add(:minutes_attendance_entry, "is required") if minutes_attendance_entry.blank?
    when "additional_item"
      errors.add(:minutes_section, "is required") if minutes_section.blank?
    end
  end

  def targets_belong_to_minutes
    return if minutes_draft_run.blank?

    minutes = minutes_draft_run.meeting_minutes
    errors.add(:minutes_item, "must belong to these minutes") if minutes_item && minutes_item.meeting_minutes != minutes
    if minutes_attendance_entry && minutes_attendance_entry.meeting_minutes != minutes
      errors.add(:minutes_attendance_entry, "must belong to these minutes")
    end
    errors.add(:minutes_section, "must belong to these minutes") if minutes_section && minutes_section.meeting_minutes != minutes
    if source_dated_agenda_item && source_dated_agenda_item.dated_agenda.meeting_id != minutes.meeting_id
      errors.add(:source_dated_agenda_item, "must belong to this meeting")
    end
  end

  def review_provenance_is_complete
    reviewed = review_state.present? && review_state != "unreviewed"
    errors.add(:reviewed_by, "must be recorded after review") if reviewed && reviewed_by.blank?
    errors.add(:reviewed_at, "must be recorded after review") if reviewed && reviewed_at.blank?
    errors.add(:reviewed_by, "must be blank before review") if !reviewed && reviewed_by.present?
    errors.add(:reviewed_at, "must be blank before review") if !reviewed && reviewed_at.present?
  end
end
