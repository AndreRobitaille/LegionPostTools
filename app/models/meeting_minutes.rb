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

  after_update_commit :schedule_endeavor_history,
    if: -> { saved_change_to_status? && (attested? || (membership_approved? && saved_change_to_current_revision_id?)) }

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
  def editable? = draft? || approved?

  def pending_correction_approval
    return if membership_approved?

    lifecycle_events.reverse.detect { |event| event.metadata["membership_approval"].present? }
  end

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
    when "approve", "attest"
      Digest::SHA256.hexdigest(JSON.generate(revision_payload))
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
        snapshot = revision_payload
        sha256 = Digest::SHA256.hexdigest(JSON.generate(snapshot))
        require_transition!(confirmation:, action: "approve", from: "draft", capability: "approve_minutes", content_digest: sha256)
        unless approval_ready?
          errors.add(:base, "Resolve attendance and the latest AI review before approval.")
          raise ActiveRecord::RecordInvalid, self
        end

        now = Time.current
        revision = revisions.create!(
          number: revisions.maximum(:number).to_i + 1,
          payload: snapshot,
          sha256:,
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
        prior_status = status
        snapshot = revision_payload
        sha256 = Digest::SHA256.hexdigest(JSON.generate(snapshot))
        require_transition!(confirmation:, action: "attest", from: %w[draft approved], capability: "attest_minutes", content_digest: sha256)
        unless approval_ready?
          errors.add(:base, "Finish attendance and AI review before attesting these minutes.")
          raise ActiveRecord::RecordInvalid, self
        end

        now = Time.current
        decision = pending_correction_approval
        revision = if approved? && current_revision.sha256 == sha256
          current_revision
        else
          revisions.create!(number: revisions.maximum(:number).to_i + 1, payload: snapshot, sha256:)
        end
        revision.create_attestation!(
          attested_by: confirmation.user,
          recorded_by:,
          official_action_confirmation: confirmation,
          attester_name: confirmation.user.person.full_name,
          attester_office: officer_label(confirmation.user),
          attested_at: now
        )
        if decision
          decision_payload = decision.metadata.fetch("membership_approval")
          create_membership_approval!(
            membership_approval_attributes(decision_payload,
              revision:,
              recorded_by: decision.recorded_by,
              confirmation: decision.official_action_confirmation,
              recorded_at: decision.occurred_at).merge(
                recorder_name: decision_payload.fetch("recorder_name"),
                recorder_office: decision_payload.fetch("recorder_office")
              )
          )
        end
        update!(status: decision ? "membership_approved" : "attested", current_revision: revision)
        record_lifecycle_event!(
          revision: current_revision,
          confirmation:,
          actor: confirmation.user,
          recorded_by:,
          event_type: "attested",
          from_status: prior_status,
          to_status: status,
          occurred_at: now,
          metadata: { "membership_approval_decision_event_id" => decision&.id }.compact
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
        now = Time.current
        approval = MinutesMembershipApproval.new(
          membership_approval_attributes(payload, revision: current_revision, recorded_by:, confirmation:, recorded_at: now).merge(meeting_minutes_id: id)
        )
        approval.validate!
        if payload["disposition"] == "approved_as_corrected" && ActiveModel::Type::Boolean.new.cast(payload["corrections_pending"])
          if approval.factual_note.blank?
            errors.add(:base, "Describe the corrections approved at the meeting.")
            raise ActiveRecord::RecordInvalid, self
          end
          update!(status: "draft")
          record_lifecycle_event!(
            revision: current_revision, confirmation:, actor: confirmation.user, recorded_by:,
            event_type: "reopened", from_status: "attested", to_status: "draft", occurred_at: now,
            metadata: {
              "reason" => approval.factual_note,
              "membership_approval" => payload.merge("recorder_name" => approval.recorder_name, "recorder_office" => approval.recorder_office)
            }
          )
          association(:membership_approval).reset
          next
        end
        approval.save!
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
            "approving_meeting_id" => approval.approving_meeting_id,
            "disposition" => approval.disposition
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
              "endeavor_id" => item.endeavor_id,
              "source_dated_agenda_item_id" => item.source_dated_agenda_item_id,
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

  def membership_approval_attributes(payload, revision:, recorded_by:, confirmation:, recorded_at:)
    {
      minutes_revision: revision,
      approving_meeting: organization.meetings.find(payload.fetch("approving_meeting_id")),
      recorded_by:,
      official_action_confirmation: confirmation,
      disposition: payload.fetch("disposition"),
      factual_note: payload["factual_note"].to_s.strip.presence,
      recorder_name: recorded_by.person.full_name,
      recorder_office: officer_label(recorded_by),
      recorded_at:
    }
  end

  def schedule_endeavor_history
    EndeavorHistoryReconcileJob.perform_later(organization_id) if EndeavorHistory::Config.enabled?
  end

  def latest_successful_draft_run
    draft_runs.detect(&:succeeded?)
  end

  def require_transition!(confirmation:, action:, from:, capability:, content_digest: nil)
    content_digest ||= digest_for(action, payload: confirmation.action_payload)
    unless status.in?(Array(from)) && confirmation.meeting_minutes_id == id && confirmation.action == action &&
        confirmation.record_lock_version == lock_version &&
        confirmation.content_digest == content_digest &&
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
