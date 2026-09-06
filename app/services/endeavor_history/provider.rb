module EndeavorHistory
  class Provider
    def initialize(client: nil)
      @client = client
    end

    def call(stage:, input:, schema:)
      serialized = JSON.generate(input)
      raise Error, "input_limit" if serialized.bytesize > Config.max_input_bytes
      response = client.responses.create(
        model: Config.model, instructions: Prompt.instructions(stage), input: serialized,
        reasoning: { effort: Config.reasoning(stage) },
        text: { format: { type: :json_schema, name: "endeavor_#{stage}", strict: true, schema: schema }, verbosity: :low },
        tools: [], tool_choice: :none, store: false, truncation: :disabled,
        max_output_tokens: Config.max_output_tokens
      )
      raise Error, "incomplete" unless response.status.to_s == "completed"
      raise Error, "refusal" if response.output_text.blank?
      { "data" => JSON.parse(response.output_text), "model" => response.model,
        "request_id" => response._request_id, "response_id" => response.id,
        "input_tokens" => response.usage&.input_tokens.to_i, "output_tokens" => response.usage&.output_tokens.to_i,
        "total_tokens" => response.usage&.total_tokens.to_i }
    rescue JSON::ParserError, OpenAI::Errors::ConversionError
      raise Error, "invalid_output"
    rescue OpenAI::Errors::APITimeoutError
      raise Error, "timeout"
    rescue OpenAI::Errors::RateLimitError
      raise Error, "rate_limit"
    rescue OpenAI::Errors::AuthenticationError, OpenAI::Errors::PermissionDeniedError
      raise Error, "configuration"
    rescue OpenAI::Errors::APIError
      raise Error, "provider_error"
    end

    private

    def client
      @client ||= begin
        token = Rails.application.credentials.openai_access_token.presence || ENV["OPENAI_ACCESS_TOKEN"].presence || ENV["OPENAI_API_KEY"].presence
        raise Error, "configuration" if token.blank?
        OpenAI::Client.new(api_key: token, log_level: :off, max_retries: 0, timeout: 360)
      end
    end
  end
end
