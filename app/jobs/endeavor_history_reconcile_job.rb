class EndeavorHistoryReconcileJob < ApplicationJob
  queue_as :background

  def perform(organization_id = nil)
    return unless EndeavorHistory::Config.enabled?
    scope = organization_id ? Organization.where(id: organization_id) : Organization.all
    scope.find_each do |organization|
      organization.endeavors.where(history_withdrawn: false).find_each do |endeavor|
        recover_stalled(endeavor)
        EndeavorHistoryRefreshJob.perform_later(endeavor.id)
      end
    end
  end

  private

  def recover_stalled(endeavor)
    endeavor.history_runs.active.each do |run|
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
    return unless latest&.status == "failed"
    if latest.error_category == "daily_budget" && latest.finished_at && latest.finished_at < Time.current.beginning_of_day
      EndeavorHistory::Processing.request(endeavor, force: true)
      return
    end
    return unless %w[queue_error worker_stalled timeout rate_limit provider_error].include?(latest.error_category)
    return unless latest.finished_at && latest.finished_at < 15.minutes.ago
    return if endeavor.history_runs.where(fingerprint: latest.fingerprint).count >= 3
    EndeavorHistory::Processing.request(endeavor, force: true)
  end
end
