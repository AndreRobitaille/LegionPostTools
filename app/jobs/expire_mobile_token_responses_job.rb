class ExpireMobileTokenResponsesJob < ApplicationJob
  queue_as :background

  def perform
    Mobile::TokenExchange.where("recoverable_until <= ?", Time.current)
      .where.not(response_ciphertext: nil).update_all(response_ciphertext: nil)
  end
end
