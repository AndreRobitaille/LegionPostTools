module AdminJobs
  class QueueHealth
    HEARTBEAT_WINDOW = 2.minutes

    attr_reader :last_worker_heartbeat_at, :waiting_count, :working_count, :failed_execution_count

    def self.capture
      return new(available: false) unless queue_tables_available?

      new(
        last_worker_heartbeat_at: SolidQueue::Process.where(kind: "Worker").maximum(:last_heartbeat_at),
        waiting_count: SolidQueue::ReadyExecution.count,
        working_count: SolidQueue::ClaimedExecution.count,
        failed_execution_count: SolidQueue::FailedExecution.count
      )
    rescue ActiveRecord::ActiveRecordError
      new(available: false)
    end

    def self.queue_tables_available?
      [
        SolidQueue::Process,
        SolidQueue::ReadyExecution,
        SolidQueue::ClaimedExecution,
        SolidQueue::FailedExecution
      ].all?(&:table_exists?)
    end
    private_class_method :queue_tables_available?

    def initialize(last_worker_heartbeat_at: nil, waiting_count: 0, working_count: 0, failed_execution_count: 0, available: true)
      @last_worker_heartbeat_at = last_worker_heartbeat_at
      @waiting_count = waiting_count
      @working_count = working_count
      @failed_execution_count = failed_execution_count
      @available = available
    end

    def available? = @available

    def worker_available?
      available? && last_worker_heartbeat_at.present? && last_worker_heartbeat_at >= HEARTBEAT_WINDOW.ago
    end
  end
end
