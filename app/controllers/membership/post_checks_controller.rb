module Membership
  class PostChecksController < BaseController
    before_action :require_membership_manager

    def index
      load_post_checks
    end
  end
end
