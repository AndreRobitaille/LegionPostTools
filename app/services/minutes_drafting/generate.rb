module MinutesDrafting
  class Generate
    DraftFailed = Class.new(StandardError) do
      attr_reader :run

      def initialize(run)
        @run = run
        super("Minutes draft generation failed")
      end
    end

    def self.call(minutes:, requester:, provider: MinutesDraftProviders::Openai.new)
      new(minutes:, requester:, provider:).call
    end

    def initialize(minutes:, requester:, provider:)
      @minutes = minutes
      @requester = requester
      @provider = provider
    end

    def call
      validate_source!
      source_document = SourceDocument.new(transcript.source_text)
      run = create_run!(source_document)
      run.update!(status: "running", started_at: Time.current)

      result = provider.draft(
        input: Prompt.input(minutes:, source_document:),
        schema: Prompt.schema,
        safety_identifier: Digest::SHA256.hexdigest("legion-minutes-user:#{requester.id}")
      )

      persist_result!(run, result, source_document)
      run
    rescue MinutesDraftProviders::Error => error
      fail_run!(run, category: error.category, request_id: error.request_id)
    rescue MeetingTranscript::SourcePurgedError, ArgumentError
      fail_run!(run, category: "source_unavailable")
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, KeyError, TypeError, RangeError
      fail_run!(run, category: "invalid_output")
    end

    private

    attr_reader :minutes, :requester, :provider

    def transcript = minutes.meeting.transcript

    def validate_source!
      raise MinutesDraftProviders::Error.new(category: "source_unavailable") unless minutes.draft?
      raise MinutesDraftProviders::Error.new(category: "source_unavailable") unless transcript&.source_available?
    end

    def create_run!(source_document)
      minutes.draft_runs.create!(
        meeting_transcript: transcript,
        requested_by: requester,
        provider: MinutesDraftProviders::Openai::PROVIDER,
        model: MinutesDraftProviders::Openai::MODEL,
        reasoning_effort: MinutesDraftProviders::Openai::REASONING_EFFORT,
        text_verbosity: MinutesDraftProviders::Openai::TEXT_VERBOSITY,
        prompt_version: Prompt::VERSION,
        prompt_sha256: Prompt.sha256,
        schema_version: Prompt::SCHEMA_VERSION,
        source_sha256: transcript.sha256_digest,
        source_line_count: source_document.lines.length,
        status: "pending"
      )
    end

    def persist_result!(run, result, source_document)
      suggestions = result.data.fetch("suggestions")
      raise TypeError unless suggestions.is_a?(Array)

      MinutesDraftRun.transaction do
        suggestions.each { |attributes| persist_suggestion!(run, attributes, source_document) }
        run.update!(
          status: "succeeded",
          provider_response_id: result.provider_response_id,
          provider_request_id: result.provider_request_id,
          model: result.model,
          input_tokens: result.input_tokens,
          output_tokens: result.output_tokens,
          reasoning_tokens: result.reasoning_tokens,
          total_tokens: result.total_tokens,
          completed_at: Time.current
        )
      end
    end

    def persist_suggestion!(run, attributes, source_document)
      kind = attributes.fetch("kind")
      target_id = attributes.fetch("target_id")
      start_line = Integer(attributes.fetch("source_start_line"))
      end_line = Integer(attributes.fetch("source_end_line"))
      raise RangeError unless (1..source_document.lines.length).cover?(start_line)
      raise RangeError unless (start_line..source_document.lines.length).cover?(end_line)

      targets = targets_for(kind, target_id)
      source_item = source_item_for(attributes["source_agenda_item_id"])
      endeavor = suggested_endeavor_for(kind, attributes.fetch("endeavor_id"))
      payload = payload_for(kind, attributes, endeavor: endeavor)

      run.suggestions.create!(
        **targets,
        source_dated_agenda_item: source_item,
        kind: kind,
        payload: payload,
        source_start_line: start_line,
        source_end_line: end_line,
        confidence: attributes.fetch("confidence"),
        missing_facts: clean_array(attributes.fetch("missing_facts"))
      )
    end

    def targets_for(kind, target_id)
      id = Integer(target_id)
      case kind
      when "item_summary", "outcome"
        { minutes_item: minutes.items.find(id) }
      when "attendance"
        { minutes_attendance_entry: minutes.attendance_entries.find(id) }
      when "additional_item"
        { minutes_section: minutes.sections.find(id) }
      else
        raise KeyError, "Unknown suggestion kind"
      end
    end

    def source_item_for(id)
      return if id.nil?

      meeting = minutes.meeting
      meeting.dated_agenda&.dated_agenda_items&.find(Integer(id)) || raise(ActiveRecord::RecordNotFound)
    end

    def payload_for(kind, attributes, endeavor:)
      case kind
      when "item_summary"
        { "body" => clean_required(attributes["body"], 8_000) }
      when "outcome"
        {
          "kind" => required_member(attributes["outcome_kind"], MinutesOutcome::KINDS),
          "text" => clean_required(attributes["body"], 4_000),
          "disposition" => required_member(attributes["disposition"], MinutesOutcome::DISPOSITIONS),
          "mover_name" => clean_optional(attributes["mover_name"], 200),
          "seconder_name" => clean_optional(attributes["seconder_name"], 200),
          "vote_summary" => clean_optional(attributes["vote_summary"], 500)
        }
      when "attendance"
        { "status" => required_member(attributes["attendance_status"], MinutesAttendanceEntry::STATUSES) }
      when "additional_item"
        {
          "title" => clean_required(attributes["title"], 300),
          "body" => clean_required(attributes["body"], 8_000),
          "endeavor_id" => endeavor&.id,
          "endeavor_title" => endeavor&.title
        }
      end
    end

    def suggested_endeavor_for(kind, id)
      return if id.nil?
      raise TypeError unless kind == "additional_item"

      Prompt.available_endeavors(minutes).find(Integer(id))
    end

    def clean_required(value, maximum)
      cleaned = value.to_s.strip
      raise TypeError if cleaned.blank? || cleaned.length > maximum

      cleaned
    end

    def clean_optional(value, maximum)
      return if value.nil?

      cleaned = value.to_s.strip
      raise TypeError if cleaned.length > maximum

      cleaned.presence
    end

    def clean_array(values)
      raise TypeError unless values.is_a?(Array)

      values.first(20).map { |value| clean_required(value, 500) }
    end

    def required_member(value, allowed)
      value.to_s.in?(allowed) ? value.to_s : raise(TypeError)
    end

    def fail_run!(run, category:, request_id: nil)
      run&.update_columns(
        status: "failed",
        error_category: category,
        provider_request_id: request_id,
        completed_at: Time.current,
        updated_at: Time.current
      )
      raise DraftFailed, run
    end
  end
end
