module EndeavorHistory
  class Error < StandardError
    attr_reader :category

    def initialize(category)
      @category = category
      super(category)
    end
  end
end
