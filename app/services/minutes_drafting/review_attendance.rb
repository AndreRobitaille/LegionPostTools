module MinutesDrafting
  class ReviewAttendance
    REVIEWABLE_STATUSES = %w[present absent excused not_recorded].freeze

    def self.call(run:, reviewer:, entries:)
      new(run:, reviewer:, entries:).call
    end

    def initialize(run:, reviewer:, entries:)
      @run = run
      @reviewer = reviewer
      @submitted_entries = entries.to_h.deep_stringify_keys
    end

    def call
      minutes.transaction do
        entries = minutes.attendance_entries.to_a
        raise KeyError unless submitted_entries.keys.sort == entries.map { |entry| entry.id.to_s }.sort

        suggestions = run.suggestions.unreviewed.where(kind: "attendance").index_by(&:minutes_attendance_entry_id)
        entries.each { |entry| review_entry!(entry, suggestions[entry.id]) }
      end

      run
    end

    private

    attr_reader :run, :reviewer, :submitted_entries

    def minutes = run.meeting_minutes

    def review_entry!(entry, suggestion)
      attributes = submitted_entries.fetch(entry.id.to_s)
      status = attributes.fetch("status")
      expected_lock_version = Integer(attributes.fetch("lock_version"))
      validate_status!(entry, status)
      raise ActiveRecord::StaleObjectError.new(entry, "update") if entry.lock_version != expected_lock_version

      if suggestion
        action = suggestion.payload.fetch("status") == status ? "use" : "edit"
        ReviewSuggestion.call(suggestion:, reviewer:, action:, edits: { status: status })
      elsif entry.status != status
        entry.update!(status: status)
      end
    end

    def validate_status!(entry, status)
      allowed = entry.status == "vacant" ? [ "vacant" ] : REVIEWABLE_STATUSES
      raise KeyError unless status.in?(allowed)
    end
  end
end
