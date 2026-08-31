module Api
  class MinutesAttendanceController < MinutesBaseController
    def update
      submitted = attendance_entries
      @minutes.transaction do
        entries = @minutes.attendance_entries.to_a
        unless submitted.keys.sort == entries.map { |entry| entry.id.to_s }.sort
          raise ArgumentError, "attendance must contain every current attendance row exactly once."
        end

        entries.each do |entry|
          attributes = submitted.fetch(entry.id.to_s)
          expected_lock_version = Integer(attributes.fetch("lock_version").to_s, 10)
          raise ActiveRecord::StaleObjectError.new(entry, "update") if entry.lock_version != expected_lock_version

          status = attributes.fetch("status").to_s
          allowed = entry.status == "vacant" ? [ "vacant" ] : MinutesAttendanceEntry::STATUSES - [ "vacant" ]
          raise ArgumentError, "Invalid attendance status for row #{entry.id}." unless status.in?(allowed)

          entry.update!(status: status) if entry.status != status
        end
      end

      render json: { attendance: @minutes.attendance_entries.reload.map { |entry| minutes_attendance_payload(entry) } }
    rescue KeyError, ArgumentError => error
      render_error(error.message, status: :unprocessable_entity, details: [ error.message ])
    rescue ActiveRecord::StaleObjectError
      render_error("Attendance changed while you were editing it. Fetch the current rows before saving.", status: :conflict)
    rescue ActiveRecord::RecordInvalid => error
      render_validation_error(error.record, fallback: "Attendance could not be updated.")
    end

    private

    def attendance_entries
      raw = params.require(:attendance)
      raise ArgumentError, "attendance must be an array." unless raw.is_a?(Array)

      rows = raw.map { |entry| entry.permit(:id, :status, :lock_version).to_h.stringify_keys }
      ids = rows.map { |entry| entry.fetch("id").to_s }
      raise ArgumentError, "attendance row ids must be unique." unless ids.uniq.length == ids.length

      rows.index_by { |entry| entry.fetch("id").to_s }
    rescue ActionController::ParameterMissing => error
      raise ArgumentError, error.message
    end
  end
end
