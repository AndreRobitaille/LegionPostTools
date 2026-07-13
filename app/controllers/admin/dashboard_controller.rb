module Admin
  class DashboardController < ApplicationController
    before_action :require_admin_area

    def show
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?
    end

    private

    # The hub is reachable to anyone who can use at least one tile. Each linked
    # page keeps its own require_capability guard; this only gates the hub itself.
    def require_admin_area
      require_authentication
      return if performed?
      return if current_user.can?("manage_settings") || current_user.can?("manage_agendas")

      redirect_to root_path, alert: "You do not have permission to open that page."
    end
  end
end
