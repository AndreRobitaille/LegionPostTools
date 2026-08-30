module MinutesDraftProviders
  class Openai
    MODEL = ENV.fetch("OPENAI_MINUTES_MODEL", "gpt-5.6-sol")
    REASONING_EFFORT = ENV.fetch("OPENAI_MINUTES_REASONING_EFFORT", "high")
    PROVIDER = "openai"

    def initialize(client: nil)
      @client = client
    end

    def draft(input:, schema:, safety_identifier:)
      response = client.responses.create(
        model: MODEL,
        instructions: MinutesDrafting::Prompt::DEVELOPER_PROMPT,
        input: input,
        reasoning: { effort: REASONING_EFFORT },
        text: {
          format: {
            type: :json_schema,
            name: "minutes_draft_suggestions",
            strict: true,
            schema: schema
          },
          verbosity: :low
        },
        tools: [],
        tool_choice: :none,
        store: false,
        truncation: :disabled,
        max_output_tokens: 20_000,
        safety_identifier: safety_identifier
      )

      raise Error.new(category: "incomplete", request_id: response._request_id) unless response.status == :completed

      content = response.output_text
      raise Error.new(category: "refusal", request_id: response._request_id) if content.blank?

      usage = response.usage
      Result.new(
        data: JSON.parse(content),
        provider_response_id: response.id,
        provider_request_id: response._request_id,
        model: response.model.to_s,
        input_tokens: usage&.input_tokens,
        output_tokens: usage&.output_tokens,
        reasoning_tokens: usage&.output_tokens_details&.reasoning_tokens,
        total_tokens: usage&.total_tokens
      )
    rescue JSON::ParserError, OpenAI::Errors::ConversionError
      raise Error.new(category: "invalid_output", request_id: response&._request_id)
    rescue OpenAI::Errors::APITimeoutError => error
      raise Error.new(category: "timeout", request_id: error.request_id)
    rescue OpenAI::Errors::RateLimitError => error
      raise Error.new(category: "rate_limit", request_id: error.request_id)
    rescue OpenAI::Errors::AuthenticationError, OpenAI::Errors::PermissionDeniedError => error
      raise Error.new(category: "configuration", request_id: error.request_id)
    rescue OpenAI::Errors::APIError => error
      raise Error.new(category: "provider_error", request_id: error.request_id)
    end

    private

    def client
      @client ||= begin
        token = Rails.application.credentials.openai_access_token.presence || ENV["OPENAI_ACCESS_TOKEN"].presence || ENV["OPENAI_API_KEY"].presence
        raise Error.new(category: "configuration") if token.blank?

        OpenAI::Client.new(api_key: token, log_level: :off, max_retries: 1, timeout: 180)
      end
    end
  end
end
