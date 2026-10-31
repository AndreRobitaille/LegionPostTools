class MinutesDistributionReconcileJob < ApplicationJob
  queue_as :background

  def perform
    MinutesDistribution.recoverable.find_each(&:enqueue_delivery)
  end
end
