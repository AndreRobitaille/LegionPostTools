require "test_helper"

class MinutesDraftProviders::OpenaiTest < ActiveSupport::TestCase
  class FakeResponses
    attr_reader :parameters, :retrieved_ids, :cancelled_ids

    def initialize(response)
      @response = response
      @retrieved_ids = []
      @cancelled_ids = []
    end

    def create(**parameters)
      @parameters = parameters
      respond
    end

    def retrieve(id)
      @retrieved_ids << id
      respond
    end

    def cancel(id)
      @cancelled_ids << id
      respond
    end

    private

    def respond
      raise @response if @response.is_a?(Exception)

      @response
    end
  end

  FakeClient = Data.define(:responses)

  test "uses strict background Responses API output without tools or long term response storage" do
    usage_details = Data.define(:reasoning_tokens).new(75)
    usage = Data.define(:input_tokens, :output_tokens, :output_tokens_details, :total_tokens).new(900, 125, usage_details, 1_025)
    response = Data.define(:status, :output_text, :id, :model, :usage, :_request_id).new(
      :completed,
      JSON.generate(suggestions: []),
      "resp_123",
      "gpt-6-astra",
      usage,
      "req_123"
    )
    responses = FakeResponses.new(response)

    result = MinutesDraftProviders::Openai.new(client: FakeClient.new(responses)).draft(
      input: "source",
      schema: MinutesDrafting::Prompt.schema,
      safety_identifier: "safe-user"
    )

    assert_equal "gpt-6-astra", responses.parameters[:model]
    assert_equal({ effort: "high" }, responses.parameters[:reasoning])
    assert_equal false, responses.parameters[:store]
    assert_equal true, responses.parameters[:background]
    assert_equal [], responses.parameters[:tools]
    assert_equal :none, responses.parameters[:tool_choice]
    assert_equal :disabled, responses.parameters[:truncation]
    assert_equal :medium, responses.parameters.dig(:text, :verbosity)
    assert_equal :json_schema, responses.parameters.dig(:text, :format, :type)
    assert_equal true, responses.parameters.dig(:text, :format, :strict)
    assert_empty responses.parameters.keys & %i[temperature top_p top_logprobs logprobs prompt_cache_retention]
    assert_equal "req_123", result.provider_request_id
    assert_equal 75, result.reasoning_tokens
  end

  test "returns durable identifiers while OpenAI is queued or working" do
    %i[queued in_progress].each do |status|
      responses = FakeResponses.new(response(status: status))
      result = draft_with(responses)

      assert_instance_of MinutesDraftProviders::Pending, result
      assert_equal "resp_123", result.provider_response_id
      assert_equal "req_123", result.provider_request_id
    end
  end

  test "retrieves the known response without submitting another generation" do
    responses = FakeResponses.new(response)
    result = MinutesDraftProviders::Openai.new(client: FakeClient.new(responses)).retrieve(response_id: "resp_123")

    assert_instance_of MinutesDraftProviders::Result, result
    assert_equal [ "resp_123" ], responses.retrieved_ids
    assert_nil responses.parameters
  end

  test "rejects retrieval of a different response and preserves the requested identifier" do
    responses = FakeResponses.new(response(id: "resp_other"))
    error = assert_raises(MinutesDraftProviders::Error) do
      MinutesDraftProviders::Openai.new(client: FakeClient.new(responses)).retrieve(response_id: "resp_123")
    end

    assert_equal "invalid_output", error.category
    assert_equal "resp_123", error.response_id
    assert_not error.retryable?
  end

  test "retains identifiers for terminal response and parsing failures" do
    [ response(status: :incomplete), response(output_text: "invalid json"), response(output_text: "") ].each do |value|
      error = assert_raises(MinutesDraftProviders::Error) { draft_with(FakeResponses.new(value)) }

      assert_equal "resp_123", error.response_id
      assert_equal "req_123", error.request_id
      assert_not error.retryable?
    end
  end

  test "connection failures and timeouts may retry retrieval without retrying submission" do
    [ OpenAI::Errors::APITimeoutError, OpenAI::Errors::APIConnectionError ].each do |klass|
      failure = klass.new(url: "https://api.openai.com/v1/responses", message: "Synthetic offline error")
      error = assert_raises(MinutesDraftProviders::Error) { draft_with(FakeResponses.new(failure)) }

      assert_predicate error, :retryable?
    end
  end

  test "cancels a known background response" do
    responses = FakeResponses.new(response(status: :cancelled))
    MinutesDraftProviders::Openai.new(client: FakeClient.new(responses)).cancel(response_id: "resp_123")

    assert_equal [ "resp_123" ], responses.cancelled_ids
    assert_nil responses.parameters
  end

  test "server failures are retryable while quota and configuration errors require action" do
    {
      OpenAI::Errors::InternalServerError => [ "provider_error", true, 500 ],
      OpenAI::Errors::RateLimitError => [ "rate_limit", false, 429 ],
      OpenAI::Errors::AuthenticationError => [ "configuration", false, 401 ]
    }.each do |klass, (category, retryable, status)|
      failure = klass.new(url: URI("https://api.openai.com/v1/responses"), status: status,
        headers: { "x-request-id" => "req_failure" }, body: {}, request: nil, response: nil)
      error = assert_raises(MinutesDraftProviders::Error) { draft_with(FakeResponses.new(failure)) }

      assert_equal category, error.category
      assert_equal retryable, error.retryable?
      assert_equal "req_failure", error.request_id
    end
  end

  test "the configured SDK submits once when the initial request times out" do
    requests = []
    transport = Object.new
    transport.define_singleton_method(:execute) do |request|
      requests << request
      raise OpenAI::Errors::APITimeoutError.new(url: request.url, message: "Synthetic offline timeout")
    end
    credentials = Data.define(:openai_access_token).new("synthetic-offline-key")
    original_constructor = OpenAI::Client.method(:new)
    constructor = ->(**options) { original_constructor.call(**options, http_client: transport) }

    with_stubbed_method(Rails.application, :credentials, -> { credentials }) do
      with_stubbed_method(OpenAI::Client, :new, constructor) do
        assert_raises(MinutesDraftProviders::Error) do
          MinutesDraftProviders::Openai.new.draft(input: "Synthetic source", schema: MinutesDrafting::Prompt.schema, safety_identifier: "safe-user")
        end
      end
    end

    assert_equal 1, requests.length
    assert_equal 60, requests.sole.timeout
    assert_equal true, JSON.parse(requests.sole.body).fetch("background")
  end

  private

  def response(status: :completed, id: "resp_123", output_text: JSON.generate(suggestions: []))
    Data.define(:status, :output_text, :id, :model, :usage, :_request_id).new(status, output_text, id, "gpt-6-astra", nil, "req_123")
  end

  def draft_with(responses)
    MinutesDraftProviders::Openai.new(client: FakeClient.new(responses)).draft(
      input: "Synthetic source", schema: MinutesDrafting::Prompt.schema, safety_identifier: "safe-user"
    )
  end

  def with_stubbed_method(object, method_name, replacement)
    original = object.method(method_name)
    object.define_singleton_method(method_name, replacement)
    yield
  ensure
    object.define_singleton_method(method_name, original)
  end
end
