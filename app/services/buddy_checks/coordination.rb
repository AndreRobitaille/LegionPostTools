module BuddyChecks
  class Coordination
    REACHED_OUTCOMES = %w[reached callback_requested do_not_contact].freeze
    attr_reader :organization

    def initialize(organization:)
      @organization = organization
    end

    def contacts
      organization.membership_contacts.where(purpose: "buddy_check").effective
    end

    def conversations
      contacts.where(outcome: REACHED_OUTCOMES).where.not(channel: "administrative_review")
    end

    def month_count(month)
      conversations.where(occurred_on: month.all_month).count
    end

    def coverage(days:)
      cutoff = Organization.current_local_date - days
      conversations_by_person = conversations.recent.to_a.group_by(&:person_id)
      preferences = contacts.where(outcome: %w[do_not_contact contact_permission_restored])
        .recent.to_a.group_by(&:person_id).transform_values(&:first)
      care = BuddyCareUpdate.where(organization:).latest.includes(assigned_to: :person).index_by(&:person_id)
      attendance = attendance_by_person
      current_people.order(:last_name, :first_name, :id).map do |person|
        last_conversation = conversations_by_person[person.id]&.first
        evidence = attendance.fetch(person.id, [])
        absences = evidence.first(2)
        missing_meetings = absences.size == 2 && absences.all? { |register| register.complete? && register.entries[person.id.to_s] == "absent" }
        last_seen = evidence.find { |register| register.entries[person.id.to_s] == "present" }
        extra_care = care[person.id]&.status == "needs_attention" ? care[person.id] : nil
        paused = preferences[person.id]&.outcome == "do_not_contact"
        { person:, paused:, last_conversation:, last_seen: last_seen&.meeting,
          missing_meetings:, extra_care:, needs_check: !paused && (last_conversation.nil? || last_conversation.occurred_on <= cutoff || missing_meetings || extra_care.present?) }
      end
    end

    private

    def current_people
      Person.roster_backed.where(roster_removed_at: nil)
        .where("LOWER(TRIM(COALESCE(roster_member_status, ''))) != 'deceased'")
    end

    def attendance_by_person
      result = Hash.new { |hash, key| hash[key] = [] }
      BuddyAttendanceRegister.latest.joins(:meeting).includes(:meeting)
        .where(meetings: { organization_id: organization.id, cancelled: false })
        .where("meetings.starts_at <= ?", Time.current).order("meetings.starts_at DESC", "buddy_attendance_registers.id DESC").each do |register|
          register.entries.each_key { |id| result[id.to_i] << register }
        end
      result
    end
  end
end
