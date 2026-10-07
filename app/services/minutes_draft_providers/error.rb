module MinutesDraftProviders
  class Error < StandardError
    attr_reader :category, :request_id, :response_id

    def initialize(category:, request_id: nil, response_id: nil, retryable: false)
      @category = category
      @request_id = request_id
      @response_id = response_id
      @retryable = retryable
      super("Minutes drafting provider failed: #{category}")
    end

    def retryable? = @retryable
  end
end
