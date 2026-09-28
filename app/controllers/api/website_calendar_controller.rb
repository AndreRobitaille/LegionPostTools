module Api
  class WebsiteCalendarController < BaseController
    before_action -> { require_capability("publish_public_content") }
    before_action -> { response.set_header("Cache-Control", "no-store") }
    rescue_from WebsitePublication::Forbidden do |error|
      render_error(error.message, status: :forbidden)
    end
    rescue_from ArgumentError do |error|
      render_error(error.message, status: :unprocessable_entity)
    end
    rescue_from WebsitePublishing::CalendarPolicy::Conflict do |error|
      render_error(error.message, status: :conflict)
    end

    def show
      render json: { website_calendar: policy_state }
    end

    def preview
      render json: { website_calendar: WebsitePublishing::CalendarPolicy.new(organization).preview(types: params[:types]) }
    end

    def update
      WebsitePublishing::CalendarPolicy.new(organization).apply!(actor: current_user, review_token: params[:review_token])
      render json: { website_calendar: policy_state }
    end

    private

    def policy_state
      { enabled: organization.website_calendar_enabled?, types: organization.website_calendar_types,
        version: organization.website_calendar_version, available_types: CalendarCategories::EDITABLE }
    end
  end
end
