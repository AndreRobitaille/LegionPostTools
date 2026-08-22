module Api
  class BaseController < ApplicationController
    UNAUTHORIZED_MESSAGE = "This is a private post operations app. Sign in, then open /api."

    before_action :prefer_json
    before_action :require_authentication

    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

    helper_method :organization

    def require_authentication
      return if authenticated?

      render_error(UNAUTHORIZED_MESSAGE, status: :unauthorized)
    end

    def require_capability(capability)
      require_authentication
      return if performed?
      return if current_user.can?(capability)

      render_error("You do not have permission to open that.", status: :forbidden)
    end

    def organization
      Organization.first!
    end

    private

    def prefer_json
      request.format = :json
    end

    def render_error(message, status:, details: [])
      payload = { error: message, details: Array(details) }
      if json_request?
        render json: payload, status: status
      else
        render plain: message, status: status, content_type: "text/plain; charset=utf-8"
      end
    end

    def json_request?
      request.format.json? || request.headers["Accept"].to_s.include?("application/json")
    end

    def render_not_found
      render_error("Not found.", status: :not_found)
    end

    def meeting_body_payload(meeting_body)
      return nil if meeting_body.nil?

      { id: meeting_body.id, name: meeting_body.name, slug: meeting_body.slug }
    end

    def meeting_type_payload(meeting_type)
      return nil if meeting_type.nil?

      { id: meeting_type.id, name: meeting_type.name, slug: meeting_type.slug, active: meeting_type.active }
    end
  end
end
