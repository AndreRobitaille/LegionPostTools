module Membership
  class OverviewController < BaseController
    def index
      load_worklist
    end
  end
end
