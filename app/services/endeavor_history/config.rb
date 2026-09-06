module EndeavorHistory
  module Config
    module_function

    def enabled? = ENV["ENDEAVOR_HISTORY_ENABLED"] == "1"
    def model = ENV.fetch("OPENAI_ENDEAVOR_MODEL", "gpt-6-astra")
    def max_input_bytes = Integer(ENV.fetch("ENDEAVOR_HISTORY_MAX_INPUT_BYTES", "180000"))
    def max_output_tokens = Integer(ENV.fetch("ENDEAVOR_HISTORY_MAX_OUTPUT_TOKENS", "24000"))
    def max_calls = Integer(ENV.fetch("ENDEAVOR_HISTORY_MAX_CALLS", "40"))
    def daily_token_budget = Integer(ENV.fetch("ENDEAVOR_HISTORY_DAILY_TOKEN_BUDGET", "500000"))
    def reasoning(stage)
      default = stage == "summary" ? "medium" : "high"
      value = ENV.fetch("OPENAI_ENDEAVOR_#{stage.upcase}_REASONING", default)
      raise Error, "configuration" unless %w[low medium high xhigh max].include?(value)
      value
    end

    def signature
      { "model" => model, "reasoning" => %w[discovery verify_discovery summary verify_summary].index_with { |stage| reasoning(stage) },
        "prompt_version" => Prompt::VERSION, "prompt_digest" => Prompt.digest, "normalization_version" => SourceDocument::VERSION }
    end
  end
end
