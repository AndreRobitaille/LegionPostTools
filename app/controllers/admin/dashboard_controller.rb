module Admin
  class DashboardController < ApplicationController
    before_action :require_admin_area

    def show
      @latest_roster_import = RosterImport.latest_successful
      @roster_stale = RosterImport.roster_stale?
    end

    private

    # Preserve scoped officers' old bookmarks while keeping settings separate.
    def require_admin_area
      require_authentication
      return if performed?
      return if current_user.can?("manage_settings")
      return redirect_to officer_tools_path if current_user.officer_workspace_access?

      redirect_to root_path, alert: "You do not have permission to open that page."
    end
  end
end
