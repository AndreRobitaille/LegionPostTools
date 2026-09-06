class EndeavorHistoryJob < ApplicationJob
  queue_as :default

  def perform(run_id)
    run = EndeavorHistoryRun.find_by(id: run_id)
    EndeavorHistory::Processing.new(run).call if run
  end
end
