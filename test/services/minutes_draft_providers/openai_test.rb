require "test_helper"

class MinutesDraftProviders::OpenaiTest < ActiveSupport::TestCase
  class FakeResponses
    attr_reader :parameters

    def initialize(response)
      @response = response
    end

    def create(**parameters)
      @parameters = parameters
      @response
    end
  end

  FakeClient = Data.define(:responses)

  test "uses strict stateless Responses API output with no tools" do
    usage_details = Data.define(:reasoning_tokens).new(75)
    usage = Data.define(:input_tokens, :output_tokens, :output_tokens_details, :total_tokens).new(900, 125, usage_details, 1_025)
    response = Data.define(:status, :output_text, :id, :model, :usage, :_request_id).new(
      :completed,
      JSON.generate(suggestions: []),
      "resp_123",
      "gpt-5.6-sol",
      usage,
      "req_123"
    )
    responses = FakeResponses.new(response)

    result = MinutesDraftProviders::Openai.new(client: FakeClient.new(responses)).draft(
      input: "source",
      schema: MinutesDrafting::Prompt.schema,
      safety_identifier: "safe-user"
    )

    assert_equal "gpt-5.6-sol", responses.parameters[:model]
    assert_equal({ effort: "high" }, responses.parameters[:reasoning])
    assert_equal false, responses.parameters[:store]
    assert_equal [], responses.parameters[:tools]
    assert_equal :none, responses.parameters[:tool_choice]
    assert_equal :disabled, responses.parameters[:truncation]
    assert_equal :medium, responses.parameters.dig(:text, :verbosity)
    assert_equal :json_schema, responses.parameters.dig(:text, :format, :type)
    assert_equal true, responses.parameters.dig(:text, :format, :strict)
    assert_equal "req_123", result.provider_request_id
    assert_equal 75, result.reasoning_tokens
  end
end
