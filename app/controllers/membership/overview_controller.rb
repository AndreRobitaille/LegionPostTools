module Membership
  class OverviewController < BaseController
    def index
    end

    def follow_up
      load_worklist
    end
  end
end
