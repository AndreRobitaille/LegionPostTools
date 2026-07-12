module Admin
  class DashboardController < BaseController
    def show
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?
      @recent_imports = RosterImport.history.limit(5)
      @position_titles = PositionTitle.where(organization: Organization.first).order(:display_order, :name)
      @administrators = User.where(disabled_at: nil).joins(:permission_grants)
        .where(permission_grants: { capability: "manage_settings" }).includes(:person).distinct
    end
  end
end
