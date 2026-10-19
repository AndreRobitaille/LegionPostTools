class EndeavorHistoryJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = EndeavorHistoryRun.find_by(id: run_id)
    return unless run
    unless EndeavorHistory::Requests.authorized_run?(run)
      run.with_lock do
        run.update!(status: "failed", error_category: "unproven_request", finished_at: Time.current) unless run.terminal?
      end
      return
    end
    EndeavorHistory::Processing.new(run).call
  end
end
