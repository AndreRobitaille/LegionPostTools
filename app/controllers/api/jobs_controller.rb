module Api
  class JobsController < BaseController
    before_action :require_jobs_access

    def index
      queue = AdminJobs::QueueHealth.capture
      filter = params[:filter].presence_in(%w[attention discarded])
      runs = minutes_runs(filter)
      loops = current_user.can?("manage_settings") && filter != "discarded" ? loops_runs(filter) : []

      render json: {
        queue: queue_payload(queue),
        filter: filter,
        attention_count: attention_count,
        minutes_draft_runs: runs.map { |run| minutes_draft_run_payload(run) },
        loops_roster_syncs: loops.map { |run| loops_run_payload(run) }
      }
    end

    private

    def require_jobs_access
      require_authentication
      return if performed?
      return if current_user.can_any?("manage_settings", "manage_minutes")

      render_error("You do not have permission to open that.", status: :forbidden)
    end

    def minutes_runs(filter)
      scope = MinutesDraftRun.includes(meeting_minutes: :meeting, requested_by: :person).recent
      scope = case filter
      when "attention" then scope.failed.kept_for_attention
      when "discarded" then scope.where.not(discarded_at: nil)
      else scope.kept_for_attention
      end
      scope.limit(50)
    end

    def loops_runs(filter)
      scope = LoopsRosterSync.includes(:roster_import, requested_by: :person).recent
      scope = scope.where(status: "failed") if filter == "attention"
      scope.limit(25)
    end

    def attention_count
      count = MinutesDraftRun.failed.kept_for_attention.count
      count += LoopsRosterSync.where(status: "failed").count if current_user.can?("manage_settings")
      count
    end

    def queue_payload(queue)
      {
        available: queue.available?,
        worker_available: queue.worker_available?,
        last_worker_heartbeat_at: queue.last_worker_heartbeat_at&.iso8601,
        waiting_count: queue.waiting_count,
        working_count: queue.working_count,
        failed_execution_count: queue.failed_execution_count
      }
    end

    def loops_run_payload(run)
      {
        id: run.id,
        roster_import_id: run.roster_import_id,
        uploaded_filename: run.roster_import.uploaded_filename,
        status: run.status,
        requested_by: run.requested_by ? directory_person_payload(run.requested_by.person) : nil,
        eligible_count: run.eligible_count,
        synced_count: run.synced_count,
        failed_count: run.failed_count,
        skipped_count: run.missing_email_count + run.invalid_email_count + run.shared_email_count,
        started_at: run.started_at&.iso8601,
        finished_at: run.finished_at&.iso8601,
        created_at: run.created_at.iso8601,
        updated_at: run.updated_at.iso8601
      }
    end
  end
end
