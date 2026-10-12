module BuddyChecks
  class Suggestions
    def initialize(access, random: Random)
      @access = access
      @random = random
    end

    def eligibility(person)
      follow_up = follow_up_state(person)
      reason = if @access.paused?(person)
        "contact_paused"
      elsif active_assignments.where(person:).where.not(assigned_to: @access.user).exists?
        "assigned_elsewhere"
      elsif follow_up == :blocked
        "open_follow_up"
      elsif follow_up == :due
        nil # An agreed callback overrides ordinary recency for its own caller.
      elsif contacts(person).any? { |contact| recent?(contact, attempt_days) }
        "recent_attempt"
      elsif contacts(person).any? { |contact| contact.outcome == "reached" && recent?(contact, conversation_days) }
        "recent_conversation"
      end
      { eligible: reason.nil?, reason:, checked_at: Time.current.iso8601(6), expires_at: 1.minute.from_now.iso8601(6) }
    end

    def suggest(exclude_ids: [])
      raise ArgumentError, "invalid_exclusions" unless exclude_ids.size <= 50 && exclude_ids.all? { |id| id.to_s.match?(/\A[1-9]\d*\z/) }
      excluded = @access.snoozes.where(cancelled_at: nil).where("until_at > ?", Time.current).pluck(:person_id) + exclude_ids.map(&:to_i)
      eligible_people = []
      candidates = []
      @access.people.where.not(id: excluded + [ @access.user.person_id ]).find_each do |person|
        next unless eligibility(person)[:eligible]
        next if follow_up_state(person)
        eligible_people << person
        history = contacts(person)
        absence = absence_evidence(person)
        next if history.empty? && absence.empty?
        latest = history.map(&:occurred_on).max
        candidates << [ absence.any? ? 0 : 1, latest || Date.new(2100), person.id, person, absence ]
      end
      candidate = candidates.min_by { |row| row.first(3) }
      unless candidate
        return { state: "exhausted", coverage: coverage } if eligible_people.empty?
        return { state: "insufficient_history", coverage: coverage,
          random_candidates: eligible_people.sample(3, random: @random).map { |person| { id: person.id, first_name: person.first_name, last_name: person.last_name } } }
      end
      person, absence = candidate.last(2)
      reason_on = if absence.any?
        Time.iso8601(absence.first[:starts_at]).in_time_zone(@access.organization.calendar_time_zone).to_date
      else
        candidate[1]
      end
      { state: "candidate", person: { id: person.id, first_name: person.first_name, last_name: person.last_name },
        reason: absence.any? ? "two_recorded_absences" : "recorded_contact_is_older", reason_on: reason_on.iso8601,
        attendance: { coverage: absence.any? ? "explicit_absences" : "unknown", meetings: absence },
        eligibility: eligibility(person), coverage: coverage }
    end

    def coverage
      { contact_history: "partial", missing_history: "unknown", attendance: "explicit_registers_only", checked_at: Time.current.iso8601(6) }
    end

    def absence_evidence(person)
      # The latest two covered meetings must both explicitly record absence.
      registers = BuddyAttendanceRegister.latest.joins(:meeting)
        .where(meetings: { organization_id: @access.organization.id, cancelled: false })
        .where("meetings.starts_at <= ?", Time.current)
        .where("entries ? :person", person: person.id.to_s).order("meetings.starts_at DESC", "buddy_attendance_registers.id DESC").limit(2).includes(:meeting).to_a
      return [] unless registers.size == 2 && registers.all? { |register| register.complete? && register.entries[person.id.to_s] == "absent" }
      registers.map { |register| { meeting_id: register.meeting_id, starts_at: register.meeting.starts_at.iso8601(6), register_revision: register.revision } }
    end

    private

    def follow_up_state(person)
      @follow_ups ||= BuddyFollowUp.where(organization: @access.organization, status: "open").to_a.group_by(&:person_id)
      states = @follow_ups.fetch(person.id, []).map do |follow_up|
        follow_up.user_id == @access.user.id && follow_up.due_at <= Time.current ? :due : :blocked
      end
      @legacy_work ||= @access.organization.membership_contacts.where(purpose: "buddy_check")
        .for_current_work.includes(:membership_assignment).to_a.group_by(&:person_id).transform_values(&:first)
      legacy = @legacy_work[person.id]
      if legacy&.follow_up_on
        caller_id = legacy.membership_assignment&.assigned_to_id || legacy.recorded_by_id
        due = legacy.follow_up_on <= Organization.current_local_date
        states << (caller_id == @access.user.id && due ? :due : :blocked)
      end
      return :blocked if states.include?(:blocked)
      :due if states.include?(:due)
    end

    def contacts(person)
      @contacts ||= @access.organization.membership_contacts.effective.where(purpose: "buddy_check")
        .where.not(channel: "administrative_review").where(outcome: %w[reached no_answer message_left callback_requested wrong_number])
        .to_a.group_by(&:person_id)
      @contacts.fetch(person.id, [])
    end

    def active_assignments
      MembershipAssignment.active_on(Organization.current_local_date)
        .where(membership_drives: { organization_id: @access.organization.id, purpose: "buddy_check" })
    end

    def recent?(contact, days)
      # Date-only evidence suppresses the whole boundary day; it never claims midnight.
      contact.occurred_at ? contact.occurred_at > days.days.ago : contact.occurred_on >= Organization.current_local_date - days
    end

    def attempt_days
      ENV.fetch("BUDDY_CHECK_ATTEMPT_DAYS", "7").to_i.clamp(1, 365)
    end

    def conversation_days
      ENV.fetch("BUDDY_CHECK_CONVERSATION_DAYS", "60").to_i.clamp(1, 730)
    end
  end
end
