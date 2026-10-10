require "test_helper"

class OpenaiSdkContractTest < ActiveSupport::TestCase
  # Exercise SDK serialization and response models without contacting OpenAI.
  class OfflineTransport
    attr_reader :requests

    def initialize(*responses)
      @responses = responses
      @requests = []
    end

    def execute(request)
      @requests << request
      response = @responses.shift || raise("Unexpected additional SDK request")
      OpenAI::HTTPClient::Response.new(
        status: 200,
        headers: { "content-type" => "application/json", "x-request-id" => "req_offline" },
        body: [ JSON.generate(response) ].each
      )
    end
  end

  test "minutes creation polling and cancellation use the SDK Responses contract" do
    transport = OfflineTransport.new(response(status: "queued"), response, response(status: "cancelled"))
    provider = MinutesDraftProviders::Openai.new(client: client(transport))

    pending = provider.draft(input: "Synthetic source", schema: MinutesDrafting::Prompt.schema, safety_identifier: "synthetic")
    assert_instance_of MinutesDraftProviders::Pending, pending
    assert_equal "resp_offline", pending.provider_response_id

    result = provider.retrieve(response_id: pending.provider_response_id)
    assert_equal({ "suggestions" => [] }, result.data)
    assert_equal "req_offline", result.provider_request_id
    assert_equal 30, result.total_tokens
    assert_equal 15, result.reasoning_tokens

    provider.cancel(response_id: pending.provider_response_id)
    assert_equal %i[post get post], transport.requests.map(&:method)
    assert_equal [ "/v1/responses", "/v1/responses/resp_offline", "/v1/responses/resp_offline/cancel" ], transport.requests.map { URI(_1.url.to_s).path }
    body = JSON.parse(transport.requests.first.body)
    assert_equal true, body["background"]
    assert_equal false, body["store"]
    assert_equal 60, transport.requests.first.timeout
  end

  test "invalid output preserves identifiers from SDK response models" do
    provider = MinutesDraftProviders::Openai.new(client: client(OfflineTransport.new(response(text: "invalid json"))))
    error = assert_raises(MinutesDraftProviders::Error) do
      provider.draft(input: "Synthetic source", schema: MinutesDrafting::Prompt.schema, safety_identifier: "synthetic")
    end

    assert_equal "invalid_output", error.category
    assert_equal "resp_offline", error.response_id
    assert_equal "req_offline", error.request_id
  end

  test "Endeavor accounting reads usage from SDK response models" do
    transport = OfflineTransport.new(response(text: '{"valid":true,"issues":[]}'))
    result = EndeavorHistory::Provider.new(client: client(transport)).call(
      stage: "verify_discovery", input: { source: "Synthetic" }, schema: EndeavorHistory::Schemas.verification
    )

    assert_equal true, result.dig("data", "valid")
    assert_equal "req_offline", result["request_id"]
    assert_equal 30, result["total_tokens"]
    assert_equal 4, result["cached_input_tokens"]
    assert_equal 2, result["cache_write_tokens"]
    assert_equal 15, result["reasoning_tokens"]
    assert_equal 1, transport.requests.size
  end

  private

  def client(transport)
    OpenAI::Client.new(api_key: "synthetic-offline-key", log_level: :off, max_retries: 0, timeout: 60, http_client: transport)
  end

  def response(status: "completed", text: '{"suggestions":[]}')
    output = []
    if status == "completed"
      output << {
        type: "message", id: "msg_offline", role: "assistant", status: "completed",
        content: [ { type: "output_text", text: text, annotations: [] } ]
      }
    end

    {
      id: "resp_offline", object: "response", created_at: 1_700_000_000, model: "gpt-6-astra", status: status,
      output: output,
      usage: {
        input_tokens: 10, output_tokens: 20, total_tokens: 30,
        input_tokens_details: { cached_tokens: 4, cache_write_tokens: 2 },
        output_tokens_details: { reasoning_tokens: 15 }
      }
    }
  end
end
