require "digest"

module MeetingTranscripts
  class Create
    def initialize(meeting:, created_by:, retention_policy:, pasted_text: nil, text_upload: nil)
      @meeting = meeting
      @created_by = created_by
      @retention_policy = retention_policy
      @pasted_text = pasted_text
      @text_upload = text_upload
    end

    def call
      @meeting.with_lock do
        if @meeting.transcript.present?
          @meeting.transcript.errors.add(:meeting, "already has a transcript source")
          raise ActiveRecord::RecordInvalid, @meeting.transcript
        end

        attributes, attachment = source_attributes
        transcript = @meeting.build_transcript(
          attributes.merge(
            organization: @meeting.organization,
            created_by: @created_by,
            retention_policy: @retention_policy
          )
        )
        transcript.text_file.attach(attachment) if attachment
        transcript.save!
        transcript
      end
    end

    private

    def source_attributes
      pasted = @pasted_text.to_s
      pasted_supplied = !@pasted_text.nil?
      upload_present = @text_upload.respond_to?(:read) && @text_upload.respond_to?(:original_filename)

      if pasted_supplied == upload_present
        return invalid_source!("provide either pasted transcript text or one text file")
      end

      upload_present ? uploaded_source_attributes : pasted_source_attributes(pasted)
    end

    def pasted_source_attributes(text)
      normalized = normalize_utf8!(text)
      bytes = normalized.bytesize
      validate_size!(bytes)

      [
        {
          source_kind: "pasted_text",
          content: normalized,
          original_filename: nil,
          byte_size: bytes,
          media_type: "text/plain",
          sha256_digest: Digest::SHA256.hexdigest(normalized)
        },
        nil
      ]
    end

    def uploaded_source_attributes
      filename = @text_upload.original_filename.to_s
      invalid_source!("upload a .txt transcript file") unless File.extname(filename).casecmp(".txt").zero?

      media_type = @text_upload.content_type.to_s.split(";").first.to_s.strip.presence || "text/plain"
      invalid_source!("upload must be a plain-text file") unless MeetingTranscript::UPLOAD_MEDIA_TYPES.include?(media_type)

      raw = @text_upload.read.to_s
      validate_size!(raw.bytesize)
      normalize_utf8!(raw)
      @text_upload.rewind if @text_upload.respond_to?(:rewind)

      [
        {
          source_kind: "text_upload",
          content: nil,
          original_filename: filename,
          byte_size: raw.bytesize,
          media_type: media_type,
          sha256_digest: Digest::SHA256.hexdigest(raw)
        },
        {
          io: StringIO.new(raw),
          filename: filename,
          content_type: media_type
        }
      ]
    end

    def normalize_utf8!(text)
      candidate = text.dup.force_encoding(Encoding::UTF_8)
      invalid_source!("transcript must be valid UTF-8 text") unless candidate.valid_encoding?

      normalized = candidate.sub(/\A\uFEFF/, "").gsub("\r\n", "\n").gsub("\r", "\n").strip
      invalid_source!("transcript is empty") if normalized.empty?
      normalized
    end

    def validate_size!(bytes)
      invalid_source!("transcript is empty") unless bytes.positive?
      invalid_source!("transcript must be 5 MB or smaller") if bytes > MeetingTranscript::MAX_BYTES
    end

    def invalid_source!(message)
      transcript = @meeting.build_transcript
      transcript.errors.add(:base, message)
      raise ActiveRecord::RecordInvalid, transcript
    end
  end
end
