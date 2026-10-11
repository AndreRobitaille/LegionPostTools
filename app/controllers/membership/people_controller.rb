module Membership
  class PeopleController < BaseController
    def show
      load_member_context
    end
  end
end
