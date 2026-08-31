module Api
  class MinutesDraftRunsController < MinutesBaseController
    before_action :set_run, only: %i[show retry discard restore attendance]

    def index
      page = collection_page(@minutes.draft_runs.recent.includes(requested_by: :person))
      return if performed?

      render json: {
        draft_runs: page[:records].map { |run| minutes_draft_run_payload(run) },
        pagination: page[:metadata]
      }
    end

    def show
      render json: { draft_run: minutes_draft_run_payload(@run, include_suggestions: true) }
    end

    def create
      run = MinutesDrafting::Generate.prepare(minutes: @minutes, requester: current_user)
      enqueue!(run)
      render json: { draft_run: minutes_draft_run_payload(run.reload) }, status: :accepted
    rescue MinutesDrafting::Generate::DraftFailed => error
      render_draft_failure(error.run)
    end

    def retry
      return render_error("Only a failed AI minutes run can be retried.", status: :unprocessable_entity) unless @run.failed?

      if (active_retry = @run.retries.active.recent.first)
        return render json: {
          draft_run: minutes_draft_run_payload(active_retry),
          already_active: true
        }
      end

      retry_run = MinutesDrafting::Generate.prepare(
        minutes: @minutes,
        requester: current_user,
        retry_of: @run
      )
      enqueue!(retry_run)
      render json: { draft_run: minutes_draft_run_payload(retry_run.reload) }, status: :accepted
    rescue MinutesDrafting::Generate::DraftFailed => error
      render_draft_failure(error.run)
    rescue ActiveRecord::RecordNotUnique
      active_retry = @run.retries.active.recent.first
      render json: { draft_run: minutes_draft_run_payload(active_retry), already_active: true }
    end

    def discard
      @run.with_lock do
        unless @run.failed?
          return render_error("Only a failed run can be discarded from attention.", status: :unprocessable_entity)
        end
        @run.update!(discarded_at: Time.current, discarded_by: current_user)
      end
      render json: { draft_run: minutes_draft_run_payload(@run.reload) }
    end

    def restore
      @run.with_lock do
        unless @run.discarded?
          return render_error("That run is already in the current ledger.", status: :unprocessable_entity)
        end
        @run.update!(discarded_at: nil, discarded_by: nil)
      end
      render json: { draft_run: minutes_draft_run_payload(@run.reload) }
    end

    def attendance
      MinutesDrafting::ReviewAttendance.call(
        run: @run,
        reviewer: current_user,
        entries: attendance_entries
      )
      render json: {
        attendance: @minutes.attendance_entries.reload.map { |entry| minutes_attendance_payload(entry) },
        draft_run: minutes_draft_run_payload(@run.reload)
      }
    rescue ActiveRecord::StaleObjectError
      render_error("Attendance changed while you were reviewing it. Fetch the current rows before saving.", status: :conflict)
    rescue ActiveRecord::RecordInvalid, KeyError, ArgumentError => error
      render_error("Attendance could not be saved. Check every officer row and try again.", status: :unprocessable_entity, details: [ error.message ])
    end

    private

    def set_run
      @run = @minutes.draft_runs.includes(:suggestions, requested_by: :person).find(params[:id])
    end

    def enqueue!(run)
      job = MinutesDraftGenerationJob.perform_later(run)
      return if job.successfully_enqueued?

      mark_enqueue_failed!(run)
      raise MinutesDrafting::Generate::DraftFailed, run
    end

    def mark_enqueue_failed!(run)
      run.update_columns(
        status: "failed",
        error_category: "queue_error",
        completed_at: Time.current,
        updated_at: Time.current
      )
    end

    def render_draft_failure(run)
      if run
        render json: { draft_run: minutes_draft_run_payload(run.reload) }, status: :unprocessable_entity
      else
        render_error("A draft run could not be prepared. Check that the minutes are draft and the transcript is available.", status: :unprocessable_entity)
      end
    end

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
