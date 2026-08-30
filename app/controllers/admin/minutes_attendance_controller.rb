module Admin
  class MinutesAttendanceController < MinutesDraftController
    def edit
      @attendance_entries = @minutes.attendance_entries
    end

    def update
      @minutes.transaction do
        attendance_params.each do |id, attributes|
          @minutes.attendance_entries.find(id).update!(attributes)
        end
      end
      redirect_to workspace_path, notice: "Officer attendance updated."
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_meeting_minutes_attendance_path(@meeting), alert: "Attendance changed while you were editing it. Review the latest version."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to edit_admin_meeting_minutes_attendance_path(@meeting), alert: error.record.errors.full_messages.to_sentence
    end

    private

    def attendance_params
      permitted = {}
      params.require(:attendance_entries).each_pair do |id, attributes|
        permitted[id] = attributes.permit(:status, :lock_version)
      end
      permitted
    end
  end
end
