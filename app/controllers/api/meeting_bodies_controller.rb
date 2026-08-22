module Api
  class MeetingBodiesController < BaseController
    before_action -> { require_capability("manage_agendas") }

    def index
      bodies = organization.meeting_bodies.order(:name)
      render json: { meeting_bodies: bodies.map { |body| meeting_body_payload(body) } }
    end
  end
end
