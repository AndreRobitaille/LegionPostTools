module MinutesDraftProviders
  Result = Data.define(
    :data,
    :provider_response_id,
    :provider_request_id,
    :model,
    :input_tokens,
    :output_tokens,
    :reasoning_tokens,
    :total_tokens
  )

  class Error < StandardError
    attr_reader :category, :request_id

    def initialize(category:, request_id: nil)
      @category = category
      @request_id = request_id
      super("Minutes drafting provider failed: #{category}")
    end
  end
end
