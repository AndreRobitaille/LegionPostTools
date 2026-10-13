class BuddyCareUpdate < ApplicationRecord
  include ImmutableMembershipEntry

  STATUSES = { "needs_attention" => "Needs extra care", "cleared" => "Care review complete" }.freeze
  belongs_to :organization
  belongs_to :person
  belongs_to :recorded_by, class_name: "User"
  belongs_to :assigned_to, class_name: "User", optional: true
  normalizes :notes, with: ->(value) { value&.strip }
  validates :status, inclusion: { in: STATUSES.keys }
  validates :notes, presence: true, length: { maximum: 1000 }
  validates :submission_key, presence: true, length: { maximum: 100 }
  validates :revision, numericality: { only_integer: true, greater_than: 0 }
  validates :follow_up_on, :assigned_to, presence: true, if: -> { status == "needs_attention" }
  validate :current_care_owner
  validate :available_care_recipient

  scope :latest, -> {
    where("NOT EXISTS (SELECT 1 FROM buddy_care_updates newer WHERE newer.organization_id = buddy_care_updates.organization_id AND newer.person_id = buddy_care_updates.person_id AND newer.revision > buddy_care_updates.revision)")
  }

  def self.record!(user:, organization:, person:, expected_revision:, attributes:)
    person.with_lock do
      raise BuddyChecks::Denied, "coordinator_required" unless user.reload.buddy_check_coordination_access?
      draft = new(attributes.merge(organization:, person:, recorded_by: user))
      existing = where(organization:).find_by(submission_key: draft.submission_key)
      if existing
        facts = %w[person_id recorded_by_id status notes assigned_to_id follow_up_on]
        raise BuddyChecks::Conflict, "changed_submission" unless facts.all? { |key| existing[key] == draft[key] }
        return existing
      end
      previous = where(organization:, person:).maximum(:revision) || 0
      raise BuddyChecks::Conflict, "stale_revision" unless Integer(expected_revision) == previous
      draft.revision = previous + 1
      draft.save!
      draft
    end
  end

  private

  def current_care_owner
    if status == "needs_attention" && assigned_to && !assigned_to.buddy_check_coordination_access?
      errors.add(:assigned_to, "must be a current, enabled Buddy Check coordinator")
    end
  end

  def available_care_recipient
    if status == "needs_attention" && person && (person.roster_removed_at || person.roster_member_status.to_s.strip.casecmp?("deceased"))
      errors.add(:person, "is no longer available for new care follow-up")
    end
  end
end
