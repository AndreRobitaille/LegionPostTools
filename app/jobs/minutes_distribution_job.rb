class MinutesDistributionJob < ApplicationJob
  queue_as :background

  def perform(issue_id)
    issue = MinutesDistribution.find_by(id: issue_id)
    MinutesDistribution::Processor.new(issue).call if issue
  end
end
