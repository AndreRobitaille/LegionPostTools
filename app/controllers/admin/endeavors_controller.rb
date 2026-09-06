module Admin
  class EndeavorsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }

    def index
      @overview = EndeavorHistory::Overview.new(Organization.first!)
      @filter = params[:filter].presence_in(EndeavorHistory::Overview::FILTERS) || "all"
      @rows = @overview.filtered(@filter)
    end
  end
end
