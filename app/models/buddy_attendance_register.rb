class BuddyAttendanceRegister < ApplicationRecord
  include ImmutableMembershipEntry
  STATUSES = %w[present absent excused not_recorded].freeze
  belongs_to :meeting
  belongs_to :recorded_by, class_name: "User"
  validates :coverage_note, presence: true, length: { maximum: 2000 }
  validates :revision, numericality: { only_integer: true, greater_than: 0 }
  validates :revision, uniqueness: { scope: :meeting_id }
  validate :explicit_entries

  scope :latest, -> {
    where("NOT EXISTS (SELECT 1 FROM buddy_attendance_registers newer WHERE newer.meeting_id = buddy_attendance_registers.meeting_id AND newer.revision > buddy_attendance_registers.revision)")
  }

  def self.record!(meeting:, user:, expected_revision:, entries:, complete:, coverage_note:)
    raise BuddyChecks::Denied, "officer_required" unless user.reload.disabled_at.nil? && user.full_membership_access?
    raise ArgumentError, "meeting_unavailable" if meeting.starts_at > Time.current || meeting.cancelled?
    meeting.with_lock do
      previous = where(meeting:).order(revision: :desc).first
      raise BuddyChecks::Conflict, "stale_revision" unless Integer(expected_revision) == (previous&.revision || 0)
      # Revisions preserve the explicitly reviewed coverage set, even across roster changes.
      covered = previous ? previous.entries.keys.sort : Person.roster_backed.directory_visible.pluck(:id).map(&:to_s).sort
      raise BuddyChecks::Conflict, "coverage_changed" unless entries.keys.sort == covered
      create!(meeting:, recorded_by: user, revision: (previous&.revision || 0) + 1, entries:, complete:, coverage_note:)
    end
  end

  private

  def explicit_entries
    unless entries.is_a?(Hash) && entries.present? && entries.keys.all? { |key| key.match?(/\A[1-9]\d*\z/) } &&
        entries.values.all? { |value| STATUSES.include?(value) }
      errors.add(:entries, "requires an explicit status for every covered member")
    end
    errors.add(:complete, "cannot include not-recorded attendance") if complete? && entries.values.include?("not_recorded")
  end
end
