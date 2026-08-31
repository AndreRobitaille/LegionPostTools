class MinutesDraftGenerationJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(run)
    MinutesDrafting::Generate.call(run: run)
  rescue MinutesDrafting::Generate::DraftFailed
    # The drafting service records a safe failure category for the review page.
  rescue StandardError
    mark_failed!(run)
    raise
  end

  private

  def mark_failed!(run)
    return if run.succeeded? || run.failed?

    run.update_columns(
      status: "failed",
      error_category: "worker_error",
      completed_at: Time.current,
      updated_at: Time.current
    )
  end
end
