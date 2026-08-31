module Admin
  class MinutesDraftAttendanceReviewsController < MinutesDraftController
    before_action :set_run

    def update
      MinutesDrafting::ReviewAttendance.call(
        run: @run,
        reviewer: current_user,
        entries: attendance_params
      )
      render_result(saved: true)
    rescue ActiveRecord::StaleObjectError
      render_result(error: "Attendance changed while you were reviewing it. Check the latest choices and save again.", status: :unprocessable_entity)
    rescue ActiveRecord::RecordInvalid, KeyError, ArgumentError
      render_result(error: "Attendance could not be saved. Check every officer row and try again.", status: :unprocessable_entity)
    end

    private

    def set_run
      @run = @minutes.draft_runs.find(params[:draft_run_id])
    end

    def attendance_params
      permitted = {}
      params.require(:attendance_entries).each_pair do |id, attributes|
        permitted[id] = attributes.permit(:status, :lock_version)
      end
      permitted
    end

    def render_result(saved: false, error: nil, status: :ok)
      prepare_sheet
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "attendance_review",
              partial: "admin/minutes_draft_runs/attendance_sheet",
              locals: sheet_locals(saved:, error:)
            ),
            turbo_stream.replace(
              "ai_review_counter",
              partial: "admin/minutes_draft_runs/review_counter",
              locals: { run: @run }
            )
          ], status: status
        end
        format.html do
          redirect_to admin_meeting_minutes_draft_run_path(@meeting, @run),
            notice: ("Officer attendance saved." if saved),
            alert: error
        end
      end
    end

    def prepare_sheet
      @attendance_entries = @minutes.attendance_entries.reload
      @attendance_suggestions_by_entry_id = @run.suggestions
        .where(kind: "attendance")
        .index_by(&:minutes_attendance_entry_id)
    end

    def sheet_locals(saved:, error:)
      {
        run: @run,
        meeting: @meeting,
        attendance_entries: @attendance_entries,
        suggestions_by_entry_id: @attendance_suggestions_by_entry_id,
        saved: saved,
        error: error
      }
    end
  end
end
