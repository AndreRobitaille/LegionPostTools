require "test_helper"

class EndeavorHistoryProviderTest < ActiveSupport::TestCase
  test "Astra requests use stage reasoning strict structured output and no sampling parameters" do
    captured = []
    response = Struct.new(:status, :output_text, :model, :_request_id, :id, :usage).new(
      :completed, '{"valid":true,"issues":[]}', "gpt-6-astra", "request-test", "response-test",
      Struct.new(:input_tokens, :output_tokens, :total_tokens).new(10, 20, 30))
    client = Object.new
    client.define_singleton_method(:responses) { self }
    client.define_singleton_method(:create) { |**args| captured << args; response }
    provider = EndeavorHistory::Provider.new(client: client)
    result = provider.call(stage: "verify_discovery", input: { source: "Synthetic" }, schema: EndeavorHistory::Schemas.verification)
    request = captured.first
    assert_equal "gpt-6-astra", request[:model]
    assert_equal "high", request.dig(:reasoning, :effort)
    assert_equal true, request.dig(:text, :format, :strict)
    assert_equal false, request[:store]
    assert_equal :disabled, request[:truncation]
    assert_empty request[:tools]
    assert_equal :none, request[:tool_choice]
    assert_empty request.keys & %i[temperature top_p logprobs top_logprobs]
    assert_equal 30, result["total_tokens"]
    assert_equal "medium", EndeavorHistory::Config.reasoning("summary")
    assert_includes request[:instructions], "Do not ask questions or request approval"
  end

  test "refused and incomplete responses never become a parsed result" do
    response = Struct.new(:status, :output_text).new(:incomplete, "{}")
    client = Object.new
    client.define_singleton_method(:responses) { self }
    client.define_singleton_method(:create) { |**_| response }
    error = assert_raises(EndeavorHistory::Error) { EndeavorHistory::Provider.new(client: client).call(stage: "summary", input: {}, schema: EndeavorHistory::Schemas.summary) }
    assert_equal "incomplete", error.category
  end
end
