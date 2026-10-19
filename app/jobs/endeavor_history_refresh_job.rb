class EndeavorHistoryRefreshJob < ApplicationJob
  queue_as :default

  def perform(endeavor_id, request_id = nil)
    return unless EndeavorHistory::Config.enabled?
    endeavor = Endeavor.find_by(id: endeavor_id)
    return unless endeavor && !endeavor.history_withdrawn? && request_id
    request = endeavor.history_events.find_by(id: request_id, action: "attestation_requested")
    return unless request
    EndeavorHistory::Processing.request(endeavor, attestation_request: request)
  rescue EndeavorHistory::Error => error
    raise unless %w[disabled no_sources withdrawn].include?(error.category)
  end
end
