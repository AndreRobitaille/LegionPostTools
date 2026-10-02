module EndeavorHistory
  module Config
    module_function

    def enabled? = ENV["ENDEAVOR_HISTORY_ENABLED"] == "1"
    def model(stage = nil)
      default = %w[summary verify_summary].include?(stage) ? "gpt-6.1-sol" : "gpt-6-astra"
      configured = ENV.fetch("OPENAI_ENDEAVOR_MODEL", default)
      stage ? ENV.fetch("OPENAI_ENDEAVOR_#{stage.upcase}_MODEL", configured) : configured
    end
    def max_input_bytes = Integer(ENV.fetch("ENDEAVOR_HISTORY_MAX_INPUT_BYTES", "180000"))
    def max_output_tokens = Integer(ENV.fetch("ENDEAVOR_HISTORY_MAX_OUTPUT_TOKENS", "24000"))
    def max_calls = Integer(ENV.fetch("ENDEAVOR_HISTORY_MAX_CALLS", "40"))
    def daily_token_budget = Integer(ENV.fetch("ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET", "500000"))
    def reasoning(stage)
      default = stage == "summary" && model(stage) == "gpt-6-astra" ? "medium" : "high"
      value = ENV.fetch("OPENAI_ENDEAVOR_#{stage.upcase}_REASONING", default)
      raise Error, "configuration" unless %w[low medium high xhigh max].include?(value)
      value
    end

    def signature
      { "model" => model, "reasoning" => %w[discovery verify_discovery summary verify_summary].index_with { |stage| reasoning(stage) },
        "models" => %w[discovery verify_discovery summary verify_summary].index_with { |stage| model(stage) },
        "prompt_version" => Prompt::VERSION, "prompt_digest" => Prompt.digest, "normalization_version" => SourceDocument::VERSION }
    end

    def stage_signature(stage)
      schema = stage.start_with?("verify_") ? Schemas.verification : Schemas.public_send(stage)
      { "model" => model(stage), "reasoning" => reasoning(stage), "instructions_sha256" => Digest::SHA256.hexdigest(Prompt.instructions(stage)),
        "schema_sha256" => Sources.digest(schema) }
    end
  end
end
