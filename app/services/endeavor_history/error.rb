module EndeavorHistory
  class Error < StandardError
    attr_reader :category, :details

    def initialize(category, details: nil)
      @category = category
      @details = details
      super(category)
    end
  end
end
