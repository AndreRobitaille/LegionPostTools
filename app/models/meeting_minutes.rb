class MeetingMinutes < ApplicationRecord
  STATUSES = %w[draft approved attested membership_approved].freeze

  belongs_to :organization, inverse_of: :meeting_minutes
  belongs_to :meeting, inverse_of: :minutes
  belongs_to :meeting_body, inverse_of: :meeting_minutes
  belongs_to :meeting_type, optional: true, inverse_of: :meeting_minutes
  belongs_to :current_revision, class_name: "MinutesRevision", optional: true

  has_many :sections,
    -> { order(:position, :title) },
    class_name: "MinutesSection",
    dependent: :destroy,
    inverse_of: :meeting_minutes
  has_many :items, through: :sections
  has_many :attendance_entries,
    -> { order(:position, :office_name) },
    class_name: "MinutesAttendanceEntry",
    dependent: :destroy,
    inverse_of: :meeting_minutes
  has_many :draft_runs,
    -> { order(created_at: :desc) },
    class_name: "MinutesDraftRun",
    dependent: :restrict_with_exception,
    inverse_of: :meeting_minutes
  has_many :revisions,
    -> { order(:number) },
    class_name: "MinutesRevision",
    dependent: :restrict_with_exception,
    inverse_of: :meeting_minutes
  has_many :lifecycle_events,
    -> { order(:occurred_at, :id) },
    class_name: "MinutesLifecycleEvent",
    dependent: :restrict_with_exception,
    inverse_of: :meeting_minutes
  has_many :official_action_confirmations, dependent: :restrict_with_exception
  has_one :membership_approval,
    class_name: "MinutesMembershipApproval",
    dependent: :restrict_with_exception,
    inverse_of: :meeting_minutes

  normalizes :title, :location_name, with: ->(value) { value.to_s.strip }

  validates :title, :starts_at, :location_name, :status, presence: true
  validates :meeting_id, uniqueness: true
  validates :status, inclusion: { in: STATUSES }
  validate :associations_describe_same_meeting
  validate :membership_approved_record_is_immutable, on: :update

  before_destroy :prevent_membership_approved_mutation, if: :membership_approved?

  scope :draft, -> { where(status: "draft") }

  def self.create_from_meeting!(meeting:)
    meeting.with_lock do
      if meeting.minutes.present?
        meeting.minutes.errors.add(:meeting, "already has a minutes record")
        raise ActiveRecord::RecordInvalid, meeting.minutes
      end

      if meeting.starts_at > Time.current
        meeting.errors.add(:starts_at, "must be in the past before minutes can begin")
        raise ActiveRecord::RecordInvalid, meeting
      end

      agenda = meeting.dated_agenda
      heading_source = agenda&.locked_for_editing? ? agenda : meeting
      minutes = create!(
        organization: meeting.organization,
        meeting: meeting,
        meeting_body: meeting.meeting_body,
        meeting_type: meeting.meeting_type,
        title: heading_source.title,
        starts_at: heading_source.starts_at,
        location_name: heading_source.location_name,
        location_address: heading_source.location_address,
        status: "draft"
      )

      minutes.seed_from_agenda!(agenda) if agenda.present?
      minutes.sections.create!(title: "Meeting record", position: 1) if minutes.sections.empty?
      minutes
    end
  end

  def draft? = status == "draft"
  def approved? = status == "approved"
  def attested? = status == "attested"
  def membership_approved? = status == "membership_approved"
  def reopened? = draft? && current_revision.present?

  def member_revision
    return membership_approval.minutes_revision if membership_approved? && membership_approval
    return current_revision if attested? && current_revision&.attestation

    revisions.joins(:attestation).order(number: :desc).first
  end

  def member_visible?
    member_revision.present?
  end

  def approval_ready?
    attendance_entries.none? { |entry| entry.status == "not_recorded" } &&
      (!latest_successful_draft_run || latest_successful_draft_run.suggestions.unreviewed.none?)
  end

  def digest_for(action, payload: {})
    case action.to_s
    when "approve"
      Digest::SHA256.hexdigest(JSON.generate(revision_payload))
    when "attest"
      current_revision&.sha256 || "missing-revision"
    when "reopen", "record_membership_approval"
      Digest::SHA256.hexdigest(JSON.generate(
        "revision_sha256" => current_revision&.sha256 || "missing-revision",
        "action_payload" => payload.to_h.deep_stringify_keys.sort.to_h
      ))
    else
      raise ArgumentError, "Unsupported official minutes action."
    end
  end

  def approve_with_confirmation!(confirmation:, recorded_by: confirmation.user)
    confirmation.consume!(user: confirmation.user, session: confirmation.session) do
      with_lock do
        reload
        require_transition!(confirmation:, action: "approve", from: "draft", capability: "approve_minutes")
        unless approval_ready?
          errors.add(:base, "Resolve attendance and the latest AI review before approval.")
          raise ActiveRecord::RecordInvalid, self
        end

        now = Time.current
        revision = revisions.create!(
          number: revisions.maximum(:number).to_i + 1,
          payload: revision_payload,
          sha256: digest_for("approve"),
          approved_by: confirmation.user,
          approver_name: confirmation.user.person.full_name,
          approver_office: officer_label(confirmation.user),
          approved_at: now
        )
        update!(status: "approved", current_revision: revision)
        record_lifecycle_event!(
          revision:,
          confirmation:,
          actor: confirmation.user,
          recorded_by:,
          event_type: "approved",
          from_status: "draft",
          to_status: "approved",
          occurred_at: now
        )
      end
    end
    current_revision
  end

  def attest_with_confirmation!(confirmation:, recorded_by: confirmation.user)
    confirmation.consume!(user: confirmation.user, session: confirmation.session) do
      with_lock do
        reload
        require_transition!(confirmation:, action: "attest", from: "approved", capability: "attest_minutes")
        if current_revision.approved_by.person_id == confirmation.user.person_id
          errors.add(:base, "The Adjutant attesting minutes must be a different person from the approver.")
          raise ActiveRecord::RecordInvalid, self
        end

        now = Time.current
        current_revision.create_attestation!(
          attested_by: confirmation.user,
          recorded_by:,
          official_action_confirmation: confirmation,
          attester_name: confirmation.user.person.full_name,
          attester_office: officer_label(confirmation.user),
          attested_at: now
        )
        update!(status: "attested")
        record_lifecycle_event!(
          revision: current_revision,
          confirmation:,
          actor: confirmation.user,
          recorded_by:,
          event_type: "attested",
          from_status: "approved",
          to_status: "attested",
          occurred_at: now
        )
      end
    end
    current_revision.attestation
  end

  def reopen_with_confirmation!(confirmation:, recorded_by: confirmation.user)
    confirmation.consume!(user: confirmation.user, session: confirmation.session) do
      with_lock do
        reload
        prior_status = status
        require_transition!(
          confirmation:,
          action: "reopen",
          from: %w[approved attested],
          capability: "manage_minutes"
        )

        reason = confirmation.action_payload.fetch("reason", "").strip
        if reason.blank?
          errors.add(:base, "Explain why these minutes are being reopened.")
          raise ActiveRecord::RecordInvalid, self
        end

        now = Time.current
        superseded_revision = current_revision
        update!(status: "draft")
        record_lifecycle_event!(
          revision: superseded_revision,
          confirmation:,
          actor: confirmation.user,
          recorded_by:,
          event_type: "reopened",
          from_status: prior_status,
          to_status: "draft",
          occurred_at: now,
          metadata: {
            "reason" => reason,
            "superseded_revision_id" => superseded_revision.id
          }
        )
      end
    end
    self
  end

  def record_membership_approval_with_confirmation!(confirmation:, recorded_by: confirmation.user)
    confirmation.consume!(user: confirmation.user, session: confirmation.session) do
      with_lock do
        reload
        require_transition!(
          confirmation:,
          action: "record_membership_approval",
          from: "attested",
          capability: "record_minutes_approval"
        )

        payload = confirmation.action_payload
        approving_meeting = organization.meetings.find(payload.fetch("approving_meeting_id"))
        disposition = payload.fetch("disposition")
        factual_note = payload["factual_note"].to_s.strip.presence
        now = Time.current

        approval = create_membership_approval!(
          minutes_revision: current_revision,
          approving_meeting:,
          recorded_by:,
          official_action_confirmation: confirmation,
          disposition:,
          factual_note:,
          recorder_name: recorded_by.person.full_name,
          recorder_office: officer_label(recorded_by),
          recorded_at: now
        )
        update!(status: "membership_approved")
        record_lifecycle_event!(
          revision: current_revision,
          confirmation:,
          actor: confirmation.user,
          recorded_by:,
          event_type: "membership_approved",
          from_status: "attested",
          to_status: "membership_approved",
          occurred_at: now,
          metadata: {
            "approving_meeting_id" => approving_meeting.id,
            "disposition" => disposition
          }
        )
        approval
      end
    end
    membership_approval
  end

  def eligible_membership_approval_meetings
    organization.meetings
      .where(meeting_body_id: meeting_body_id)
      .where("starts_at > ? AND starts_at <= ?", starts_at, Time.current)
      .order(:starts_at)
  end

  def revision_payload
    {
      "title" => title,
      "starts_at" => starts_at.iso8601(6),
      "location_name" => location_name,
      "location_address" => location_address,
      "meeting_body_name" => meeting_body.name,
      "attendance" => attendance_entries.map do |entry|
        {
          "office_name" => entry.office_name,
          "person_name" => entry.person_name,
          "status" => entry.status,
          "position" => entry.position
        }
      end,
      "sections" => sections.map do |section|
        {
          "title" => section.title,
          "position" => section.position,
          "items" => section.items.map do |item|
            {
              "record_key" => item.record_key,
              "title" => item.title,
              "behavior_type" => item.behavior_type,
              "position" => item.position,
              "agenda_body_html" => item.rich_text_agenda_body&.body&.to_html,
              "body_html" => item.rich_text_body&.body&.to_html,
              "outcomes" => item.outcomes.map do |outcome|
                {
                  "kind" => outcome.kind,
                  "text" => outcome.text,
                  "mover_name" => outcome.mover_name,
                  "seconder_name" => outcome.seconder_name,
                  "disposition" => outcome.disposition,
                  "vote_summary" => outcome.vote_summary,
                  "position" => outcome.position
                }
              end
            }
          end
        }
      end
    }
  end

  def seed_from_agenda!(agenda)
    attendance_position = 0

    agenda.dated_agenda_sections.ordered.includes(
      agenda_items: [ :endeavor, :rich_text_body, :rich_text_commander_notes, { roll_call_entries: %i[position_title person] } ]
    ).each do |agenda_section|
      section = sections.create!(
        source_dated_agenda_section: agenda_section,
        title: agenda_section.title,
        position: agenda_section.position
      )

      agenda_section.agenda_items.active.order(:position, :title).each do |agenda_item|
        item = section.items.create!(
          source_dated_agenda_item: agenda_item,
          endeavor: agenda_item.endeavor,
          title: agenda_item.title,
          behavior_type: agenda_item.behavior_type,
          position: agenda_item.position
        )
        if agenda_item.show_wording_in_minutes? && agenda_item.rich_text_body.present?
          item.create_rich_text_agenda_body!(body: agenda_item.rich_text_body.body)
        end

        agenda_item.roll_call_entries.each do |roll_call_entry|
          attendance_position += 1
          attendance_entries.create!(
            dated_agenda_roll_call_entry: roll_call_entry,
            position_title: roll_call_entry.position_title,
            person: roll_call_entry.person,
            office_name: roll_call_entry.office_name,
            person_name: roll_call_entry.person_name,
            status: roll_call_entry.vacant? ? "vacant" : "not_recorded",
            position: attendance_position
          )
        end
      end
    end
  end

  private

  def latest_successful_draft_run
    draft_runs.detect(&:succeeded?)
  end

  def require_transition!(confirmation:, action:, from:, capability:)
    unless status.in?(Array(from)) && confirmation.meeting_minutes_id == id && confirmation.action == action &&
        confirmation.record_lock_version == lock_version &&
        confirmation.content_digest == digest_for(action, payload: confirmation.action_payload) &&
        confirmation.user.can?(capability)
      errors.add(:base, "The minutes or authority changed. Start the confirmation again.")
      raise ActiveRecord::RecordInvalid, self
    end
  end

  def officer_label(user)
    user.person.current_role_label.presence || "Authorized officer"
  end

  def record_lifecycle_event!(revision:, confirmation:, actor:, recorded_by:, event_type:, from_status:, to_status:, occurred_at:, metadata: {})
    lifecycle_events.create!(
      minutes_revision: revision,
      actor:,
      recorded_by:,
      official_action_confirmation: confirmation,
      event_type:,
      from_status:,
      to_status:,
      actor_name: actor.person.full_name,
      actor_office: officer_label(actor),
      occurred_at:,
      metadata: metadata.merge(
        "confirmation_method" => confirmation.confirmation_method,
        "evidence_note" => confirmation.evidence_note
      ).compact
    )
  end

  def associations_describe_same_meeting
    return if organization.blank? || meeting.blank? || meeting_body.blank?

    unless meeting.organization_id == organization_id && meeting.meeting_body_id == meeting_body_id
      errors.add(:base, "organization, meeting, and meeting body must describe the same occurrence")
    end

    if meeting_type_id != meeting.meeting_type_id
      errors.add(:meeting_type, "must match the meeting")
    end
  end

  def membership_approved_in_database?
    status_in_database == "membership_approved"
  end

  def prevent_membership_approved_mutation
    errors.add(:base, "Membership-approved minutes are immutable.")
    throw :abort
  end

  def membership_approved_record_is_immutable
    errors.add(:base, "Membership-approved minutes are immutable.") if membership_approved_in_database?
  end
end
