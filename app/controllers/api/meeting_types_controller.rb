module Api
  class MeetingTypesController < BaseController
    before_action -> { require_capability("manage_agendas") }

    def index
      types = organization.meeting_types.active.ordered
      render json: { meeting_types: types.map { |meeting_type| meeting_type_payload(meeting_type) } }
    end
  end
end
