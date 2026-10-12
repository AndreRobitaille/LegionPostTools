module BuddyChecks
  class Operations
    UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i
    CHANNELS = %w[phone text in_person].freeze
    OUTCOMES = %w[reached no_answer message_left wrong_number not_attempted].freeze

    def initialize(access)
      @access = access
    end

    def record(operation_id:, person_id:, facts:, follow_up: nil, assignment_id: nil)
      execute(operation_id, "contact", person_id, { facts:, follow_up:, assignment_id: }) do |person|
        assignment = @access.assignments.where(person:).find(assignment_id) if assignment_id.present?
        attributes = event_facts(facts)
        contact = @access.organization.membership_contacts.create!(attributes.merge(person:, recorded_by: @access.user,
          membership_assignment: assignment, membership_year: assignment&.membership_drive&.membership_year || attributes[:occurred_on].year,
          purpose: "buddy_check", submission_key: SecureRandom.uuid))
        scheduled = create_follow_up(person, follow_up, contact) if follow_up.present?
        { contact: contact_payload(contact), follow_up: scheduled && follow_up_payload(scheduled) }
      end
    end

    def correct(operation_id:, id:, expected_revision:, facts:)
      original = @access.owned_contacts.find(id)
      root_id = original.logical_contact_id || original.id
      execute(operation_id, "correction/#{root_id}", original.person_id, { expected_revision:, facts: }) do |person|
        root = @access.owned_contacts.find(root_id)
        current = @access.owned_contacts.effective.where("id = :id OR logical_contact_id = :id", id: root_id).sole
        raise Conflict, "stale_revision" unless current.revision == Integer(expected_revision)
        attributes = event_facts(facts, allow_date: root.occurred_at.nil?)
        # Date-only legacy events stay date-only unless the caller explicitly supplies exact facts.
        replacement = @access.organization.membership_contacts.create!(attributes.merge(person:, recorded_by: @access.user,
          membership_assignment: root.membership_assignment, membership_year: root.membership_assignment_id ? root.membership_year : attributes[:occurred_on].year,
          purpose: "buddy_check", logical_contact: root, supersedes_contact: current, revision: current.revision + 1,
          follow_up_on: current.follow_up_on,
          submission_key: SecureRandom.uuid))
        { contact: contact_payload(replacement) }
      end
    end

    def schedule(operation_id:, person_id:, due_at:, entry_zone:)
      execute(operation_id, "follow_up", person_id, { due_at:, entry_zone: }) do |person|
        { follow_up: follow_up_payload(create_follow_up(person, { "due_at" => due_at, "entry_zone" => entry_zone })) }
      end
    end

    def change_follow_up(operation_id:, id:, expected_revision:, action:, due_at: nil, entry_zone: nil)
      follow_up = @access.follow_ups.find(id)
      execute(operation_id, "follow_up/#{id}", follow_up.person_id, { expected_revision:, action:, due_at:, entry_zone: }) do
        follow_up.reload
        raise Conflict, "stale_revision" unless follow_up.lock_version == Integer(expected_revision)
        raise Conflict, "follow_up_closed" unless follow_up.status == "open"
        case action
        when "reschedule"
          follow_up.update!(due_facts(due_at:, entry_zone:))
        when "complete", "cancel"
          follow_up.update!(status: action == "complete" ? "completed" : "cancelled")
        else
          raise ArgumentError, "invalid_follow_up_action"
        end
        { follow_up: follow_up_payload(follow_up) }
      end
    end

    def snooze(operation_id:, person_id:, until_at:)
      execute(operation_id, "snooze", person_id, { until_at: }) do |person|
        instant = instant!(until_at)
        raise ArgumentError, "snooze_out_of_range" unless instant > Time.current && instant <= 90.days.from_now
        snooze = BuddySnooze.create!(organization: @access.organization, user: @access.user, person:, until_at: instant)
        { snooze: snooze_payload(snooze) }
      end
    end

    def undo_snooze(operation_id:, id:, expected_revision:)
      snooze = @access.snoozes.find(id)
      execute(operation_id, "undo_snooze/#{id}", snooze.person_id, { expected_revision: }) do
        snooze.reload
        raise Conflict, "stale_revision" unless snooze.lock_version == Integer(expected_revision)
        snooze.update!(cancelled_at: Time.current)
        { snooze: snooze_payload(snooze) }
      end
    end

    def receipt(operation_id)
      validate_uuid!(operation_id)
      @access.enabled!
      operation = BuddyOperation.find_by!(organization: @access.organization, user: @access.user, operation_id:)
      @access.permission!(operation.person)
      operation.receipt
    end

    def contact_payload(contact)
      { id: contact.logical_contact_id || contact.id, source_id: contact.id, person_id: contact.person_id,
        revision: contact.revision, channel: contact.channel, outcome: contact.outcome,
        occurred_at: contact.occurred_at&.iso8601(6), occurred_on: contact.occurred_on.iso8601,
        entry_zone: contact.entry_zone, precision: contact.occurred_at ? "instant" : "date",
        membership_year: contact.membership_year, notes: contact.notes, legacy_follow_up_on: contact.follow_up_on&.iso8601, recorded_at: contact.created_at.iso8601(6) }
    end

    def follow_up_payload(follow_up)
      { id: follow_up.id, person_id: follow_up.person_id, contact_id: follow_up.membership_contact_id,
        due_at: follow_up.due_at.iso8601(6), entry_zone: follow_up.entry_zone, status: follow_up.status, revision: follow_up.lock_version }
    end

    def snooze_payload(snooze)
      { id: snooze.id, person_id: snooze.person_id, until_at: snooze.until_at.iso8601(6),
        cancelled_at: snooze.cancelled_at&.iso8601(6), revision: snooze.lock_version }
    end

    private

    def execute(operation_id, kind, person_id, payload)
      validate_uuid!(operation_id)
      fingerprint = Digest::SHA256.hexdigest(JSON.generate(canonical({ kind:, person_id: person_id.to_s, payload: })))
      @access.user.with_lock do
        @access.enabled!
        person = @access.person!(person_id)
        # Lock the recipient to serialize mobile writes by different callers too.
        person.with_lock do
          @access.permission!(person)
          existing = BuddyOperation.find_by(organization: @access.organization, user: @access.user, operation_id:)
          if existing
            raise Conflict, "operation_payload_conflict" unless existing.fingerprint == fingerprint
            next existing.receipt
          end
          receipt = yield(person).merge(operation_id:, accepted_at: Time.current.iso8601(6), state: "accepted")
          BuddyOperation.create!(organization: @access.organization, user: @access.user, person:, operation_id:, fingerprint:, receipt:).receipt
        end
      end
    end

    def canonical(value)
      case value
      when Hash then value.stringify_keys.sort.to_h.transform_values { |child| canonical(child) }
      when Array then value.map { |child| canonical(child) }
      else value
      end
    end

    def validate_uuid!(value)
      raise ArgumentError, "invalid_operation_id" unless value.to_s.match?(UUID)
    end

    def event_facts(facts, allow_date: false)
      raise ArgumentError, "invalid_facts" unless facts.is_a?(Hash)
      facts = facts.stringify_keys
      raise ArgumentError, "invalid_facts" unless (facts.keys - %w[channel outcome occurred_at occurred_on entry_zone notes]).empty?
      raise ArgumentError, "ambiguous_precision" if facts["occurred_at"].present? && facts["occurred_on"].present?
      raise ArgumentError, "invalid_notes" unless facts["notes"].nil? || facts["notes"].is_a?(String)
      raise ArgumentError, "invalid_channel" unless CHANNELS.include?(facts["channel"])
      raise ArgumentError, "invalid_outcome" unless OUTCOMES.include?(facts["outcome"])
      if allow_date && facts["occurred_at"].blank?
        date = Date.iso8601(facts.fetch("occurred_on"))
        raise ArgumentError, "event_in_future" if date > Organization.current_local_date
        return { channel: facts["channel"], outcome: facts["outcome"], occurred_on: date, notes: facts["notes"] }
      end
      instant = instant!(facts.fetch("occurred_at"))
      zone!(facts.fetch("entry_zone"))
      raise ArgumentError, "event_in_future" if instant > Time.current
      { channel: facts["channel"], outcome: facts["outcome"], occurred_at: instant, entry_zone: facts["entry_zone"],
        occurred_on: instant.in_time_zone(@access.organization.calendar_time_zone).to_date, notes: facts["notes"] }
    end

    def create_follow_up(person, facts, contact = nil)
      raise ArgumentError, "invalid_facts" unless facts.is_a?(Hash)
      facts = facts.stringify_keys
      raise ArgumentError, "invalid_follow_up" unless (facts.keys - %w[due_at entry_zone]).empty?
      BuddyFollowUp.create!(organization: @access.organization, user: @access.user, person:, membership_contact: contact,
        **due_facts(due_at: facts.fetch("due_at"), entry_zone: facts.fetch("entry_zone")))
    end

    def due_facts(due_at:, entry_zone:)
      zone!(entry_zone)
      instant = instant!(due_at)
      raise ArgumentError, "due_time_out_of_range" unless instant > Time.current && instant <= 2.years.from_now
      { due_at: instant, entry_zone: }
    end

    def instant!(value)
      raise ArgumentError, "instant_requires_offset" unless value.to_s.match?(/T.*(?:Z|[+-]\d{2}:\d{2})\z/)
      Time.iso8601(value)
    end

    def zone!(value)
      TZInfo::Timezone.get(value)
    rescue TZInfo::InvalidTimezoneIdentifier
      raise ArgumentError, "invalid_entry_zone"
    end
  end
end
