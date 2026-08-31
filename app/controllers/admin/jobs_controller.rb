module Admin
  class JobsController < ApplicationController
    before_action -> { require_any_capability("manage_settings", "manage_minutes") }
    before_action :set_minutes_draft_run, only: %i[retry discard restore]

    def index
      @queue_health = AdminJobs::QueueHealth.capture
      @filter = params[:filter].presence_in(%w[attention discarded])
      @attention_count = MinutesDraftRun.failed.kept_for_attention.count
      @attention_count += LoopsRosterSync.where(status: "failed").count if current_user.can?("manage_settings")
      @runs = filtered_runs
    end

    def retry
      unless @run.failed?
        return redirect_to admin_jobs_path, alert: "Only a failed AI minutes run can be retried."
      end

      if (active_retry = @run.retries.active.recent.first)
        return redirect_to admin_meeting_minutes_draft_run_path(active_retry.meeting_minutes.meeting, active_retry),
          notice: "A retry of this run is already underway."
      end

      retry_run = MinutesDrafting::Generate.prepare(
        minutes: @run.meeting_minutes,
        requester: current_user,
        retry_of: @run
      )
      job = MinutesDraftGenerationJob.perform_later(retry_run)

      unless job.successfully_enqueued?
        mark_enqueue_failed!(retry_run)
        return redirect_to admin_jobs_path(filter: "attention"), alert: "The retry was recorded, but the draft worker could not be started."
      end

      redirect_to admin_meeting_minutes_draft_run_path(retry_run.meeting_minutes.meeting, retry_run),
        notice: "A new draft attempt has started. The failed run remains in the record."
    rescue MinutesDrafting::Generate::DraftFailed
      redirect_to admin_jobs_path(filter: "attention"), alert: "A new draft attempt could not be prepared. Check that the minutes are still a draft and the transcript is available."
    rescue ActiveRecord::RecordNotUnique
      active_retry = @run.retries.active.recent.first
      redirect_to admin_meeting_minutes_draft_run_path(active_retry.meeting_minutes.meeting, active_retry),
        notice: "A retry of this run is already underway."
    end

    def discard
      @run.with_lock do
        unless @run.failed?
          return redirect_to admin_jobs_path, alert: "Only a failed run can be discarded from attention."
        end

        @run.update!(discarded_at: Time.current, discarded_by: current_user)
      end

      redirect_to admin_jobs_path, notice: "The failed run was removed from attention. Its history was preserved."
    end

    def restore
      @run.with_lock do
        unless @run.discarded?
          return redirect_to admin_jobs_path, alert: "That run is already in the current ledger."
        end

        @run.update!(discarded_at: nil, discarded_by: nil)
      end

      redirect_to admin_jobs_path(filter: "attention"), notice: "The failed run was returned to needs attention."
    end

    private

    def set_minutes_draft_run
      @run = MinutesDraftRun.find(params[:id])
    end

    def filtered_runs
      minutes_scope = MinutesDraftRun.includes(meeting_minutes: :meeting, requested_by: :person).recent
      minutes_scope = case @filter
      when "attention" then minutes_scope.failed.kept_for_attention
      when "discarded" then minutes_scope.where.not(discarded_at: nil)
      else minutes_scope.kept_for_attention
      end

      runs = minutes_scope.limit(50).to_a
      if current_user.can?("manage_settings") && @filter != "discarded"
        loops_scope = LoopsRosterSync.includes(:roster_import, requested_by: :person).recent
        loops_scope = loops_scope.where(status: "failed") if @filter == "attention"
        runs.concat(loops_scope.limit(25).to_a)
      end
      runs.sort_by(&:created_at).reverse.first(50)
    end

    def mark_enqueue_failed!(run)
      run.update_columns(
        status: "failed",
        error_category: "queue_error",
        completed_at: Time.current,
        updated_at: Time.current
      )
    end
  end
end
