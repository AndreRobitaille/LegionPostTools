module MinutesDraftProviders
  class Error < StandardError
    attr_reader :category, :request_id

    def initialize(category:, request_id: nil)
      @category = category
      @request_id = request_id
      super("Minutes drafting provider failed: #{category}")
    end
  end
end
