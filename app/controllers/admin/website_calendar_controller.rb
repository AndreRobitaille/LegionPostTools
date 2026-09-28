module Admin
  class WebsiteCalendarController < ApplicationController
    include CalendarTimeZone
    before_action -> { require_capability("publish_public_content") }
    before_action :load_policy
    rescue_from ArgumentError, WebsitePublishing::CalendarPolicy::Conflict, with: :invalid
    rescue_from WebsitePublication::Forbidden, with: -> { head :forbidden }

    def show
      @types = @organization.website_calendar_types
    end

    def preview
      @types = Array(params[:types]).reject(&:blank?)
      @preview = @policy.preview(types: @types)
      render :show
    end

    def update
      @policy.apply!(actor: current_user, review_token: params[:review_token])
      redirect_to admin_website_calendar_path, notice: "Website calendar defaults saved."
    end

    private

    def load_policy
      response.set_header("Cache-Control", "no-store")
      @organization = Organization.first!
      @policy = WebsitePublishing::CalendarPolicy.new(@organization)
    end

    def invalid(error)
      redirect_to admin_website_calendar_path, alert: error.message
    end
  end
end
