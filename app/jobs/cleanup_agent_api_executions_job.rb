class CleanupAgentApiExecutionsJob < ApplicationJob
  queue_as :background

  def perform
    AgentApiExecution.expired.delete_all
  end
end
