module Mobile
  class SessionsController < ApplicationController
    before_action :require_authentication
    before_action -> { head :forbidden unless current_user.mobile_buddy_checks_access? }
    before_action -> { response.headers["Cache-Control"] = "no-store" }

    def index
      @tokens = tokens.where(revoked_at: nil).where("created_at + expires_in * interval '1 second' > ?", Time.current).order(created_at: :desc)
    end

    def destroy
      tokens.find(params[:id]).revoke
      redirect_to mobile_sessions_path, notice: "Mobile session revoked.", status: :see_other
    end

    private

    def tokens
      Doorkeeper::AccessToken.where(resource_owner_id: current_user.id, scopes: "buddy_check")
    end
  end
end
