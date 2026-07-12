module Admin
  class DashboardController < BaseController
    def show
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?
    end
  end
end
