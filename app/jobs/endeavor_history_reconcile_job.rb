class EndeavorHistoryReconcileJob < ApplicationJob
  queue_as :background

  # Recover recorded requests, never infer spending authority from a changed fingerprint.
  def perform(organization_id = nil)
    return unless EndeavorHistory::Config.enabled?
    scope = organization_id ? Organization.where(id: organization_id) : Organization.all
    scope.find_each do |organization|
      organization.endeavors.where(history_withdrawn: false).find_each do |endeavor|
        recover_stalled(endeavor)
        EndeavorHistory::Requests.enqueue(endeavor) unless endeavor.history_runs.active.exists?
      end
    end
  end

  private

  def recover_stalled(endeavor)
    endeavor.history_runs.active.each do |run|
      unless EndeavorHistory::Requests.authorized_run?(run)
        run.with_lock do
          run.update!(status: "failed", error_category: "unproven_request", finished_at: Time.current) unless run.terminal?
        end
        next
      end
      if run.status == "pending"
        EndeavorHistoryJob.perform_later(run.id) if run.created_at < 5.minutes.ago
      elsif run.heartbeat_at && run.heartbeat_at < 15.minutes.ago
        run.with_lock do
          if run.status == "running" && run.heartbeat_at < 15.minutes.ago
            run.update!(status: "failed", error_category: "worker_stalled", finished_at: Time.current)
          end
        end
      end
    end
    latest = endeavor.history_runs.recent.first
    return unless latest && EndeavorHistory::Requests.retryable?(latest)
    EndeavorHistory::Processing.request(endeavor, retry_run: latest)
  end
end
