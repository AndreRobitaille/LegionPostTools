module MinutesEnqueueSupport
  private

  def with_rejected_minutes_enqueue
    rejection = ->(_job) { throw :abort }
    MinutesDraftGenerationJob.set_callback(:enqueue, :before, rejection)
    yield
  ensure
    MinutesDraftGenerationJob.skip_callback(:enqueue, :before, rejection)
  end

  def saved_minutes_source_graph(minutes, transcript)
    [ minutes.reload.attributes, minutes.revision_payload,
      minutes.sections.order(:id).map(&:attributes), minutes.items.order(:id).map(&:attributes),
      minutes.attendance_entries.order(:id).map(&:attributes), MinutesOutcome.where(minutes_item_id: minutes.items.select(:id)).order(:id).map(&:attributes),
      minutes.revisions.order(:id).map(&:attributes), minutes.lifecycle_events.order(:id).map(&:attributes),
      transcript.reload.attributes, transcript.source_text, transcript.text_file.attached? ]
  end

  def assert_rejected_minutes_run(run, requester:, transcript:, retry_of: nil)
    assert_equal "failed", run.reload.status
    assert_equal "queue_error", run.error_category
    assert_not_nil run.completed_at
    assert_nil run.started_at
    assert_equal requester.id, run.requested_by_id
    assert_equal transcript.id, run.meeting_transcript_id
    assert_equal transcript.sha256_digest, run.source_sha256
    if retry_of
      assert_equal retry_of.id, run.retry_of_id
    else
      assert_nil run.retry_of_id
    end
    assert_empty run.suggestions
  end
end
