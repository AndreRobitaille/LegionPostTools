module MeetingTranscripts
  class Purge
    RemovalError = Class.new(StandardError)

    def initialize(transcript:)
      @transcript = transcript
    end

    def call
      attachment = nil
      blob = nil
      @transcript.with_lock do
        return false unless @transcript.retention_purge_due?

        attachment = @transcript.text_file_attachment
        blob = attachment&.blob
        @transcript.update!(purge_started_at: Time.current) if @transcript.purge_started_at.blank?
      end

      if blob
        ensure_exclusive_blob!(blob, attachment)
        delete_storage!(blob)
      elsif @transcript.text_upload?
        raise RemovalError, "Uploaded transcript removal has no storage locator."
      end

      @transcript.with_lock do
        return true if @transcript.purged_at.present?
        raise RemovalError, "Transcript no longer qualifies for automatic removal." unless @transcript.retention_purge_due?

        if blob
          ensure_exclusive_blob!(blob, attachment)
          unless @transcript.text_file_attachment&.id == attachment.id
            raise RemovalError, "Transcript attachment changed during removal."
          end
          attachment.delete
          blob.destroy!
          @transcript.association(:text_file_attachment).reset
          @transcript.association(:text_file_blob).reset
        end
        @transcript.update!(content: nil, purged_at: Time.current, purged_by_service: MeetingTranscript::RETENTION_SERVICE)
      end
      true
    end

    private

    def ensure_exclusive_blob!(blob, attachment)
      return unless blob.attachments.where.not(id: attachment.id).exists?

      raise RemovalError, "Transcript removal cannot delete a shared storage object."
    end

    def delete_storage!(blob)
      blob.delete
    rescue StandardError
      # Storage adapters raise different errors; retain the locator and report a safe failure.
      raise RemovalError, "Transcript storage removal failed; removal remains pending.", cause: nil
    end
  end
end
