class PurgeMeetingTranscriptsJob < ApplicationJob
  BatchRemovalError = Class.new(StandardError)
  BATCH_SIZE = 500
  queue_as :background

  def perform
    failed_ids = []
    MeetingTranscript.due_for_retention_purge.order(:id).limit(BATCH_SIZE).pluck(:id).each do |id|
      MeetingTranscripts::Purge.new(transcript: MeetingTranscript.find(id)).call
    rescue MeetingTranscripts::Purge::RemovalError, ActiveRecord::ActiveRecordError
      failed_ids << id
    end
    return if failed_ids.empty?

    raise BatchRemovalError, "Automatic transcript removal failed for source IDs: #{failed_ids.join(', ')}.", cause: nil
  end
end
