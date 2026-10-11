module Membership
  class ReportsController < BaseController
    before_action :require_membership_manager

    def index
      @summary = @workspace.summary
      @summaries = @organization.membership_summaries.where(membership_year: @membership_year).order(created_at: :desc).limit(10)
    end
  end
end
