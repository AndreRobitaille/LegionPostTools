class MinutesDraftGenerationJob < ApplicationJob
  POLL_INTERVAL = 10.seconds

  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(run)
    MinutesDrafting::Generate.call(run: run)
    return unless run.reload.running?

    job = self.class.set(wait: POLL_INTERVAL).perform_later(run)
    mark_failed!(run, category: "queue_error") unless job && job.successfully_enqueued?
  rescue MinutesDrafting::Generate::DraftFailed
    # The drafting service records a safe failure category for the review page.
  rescue StandardError
    mark_failed!(run)
    raise
  end

  private

  def mark_failed!(run, category: "worker_error")
    run.with_lock do
      return unless run.pending? || run.running?

      run.update_columns(
        status: "failed",
        error_category: category,
        completed_at: Time.current,
        updated_at: Time.current
      )
    end
  end
end
