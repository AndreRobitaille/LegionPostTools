class EndeavorHistoryRefreshJob < ApplicationJob
  queue_as :default

  def perform(endeavor_id)
    return unless EndeavorHistory::Config.enabled?
    endeavor = Endeavor.find_by(id: endeavor_id)
    return unless endeavor && !endeavor.history_withdrawn?
    EndeavorHistory::Processing.request(endeavor)
  rescue EndeavorHistory::Error => error
    raise unless %w[disabled no_sources withdrawn].include?(error.category)
  end
end
