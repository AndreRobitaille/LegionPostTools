class OfficerToolsController < ApplicationController
  before_action :require_authentication
  before_action :require_officer_workspace

  def show
    response.headers["Cache-Control"] = "no-store"
  end

  private

  def require_officer_workspace
    return if current_user.officer_workspace_access?

    redirect_to root_path, alert: "You do not have permission to open officer tools."
  end
end
