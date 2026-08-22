module Api
  class HandbookController < BaseController
    skip_before_action :prefer_json

    def show
      handbook = AgentHandbook.new(
        user: current_user,
        organization: organization,
        csrf_token: form_authenticity_token
      )

      if json_request?
        render json: handbook.as_json
      else
        render body: handbook.markdown, content_type: "text/markdown; charset=utf-8"
      end
    end
  end
end
