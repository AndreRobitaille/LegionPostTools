module Mobile
  class SessionsController < ApplicationController
    before_action :require_authentication
    before_action -> { head :forbidden unless current_user.mobile_buddy_checks_access? }
    before_action -> { response.headers["Cache-Control"] = "no-store" }

    def index
      @tokens = tokens.where(remembered_session_id: nil, revoked_at: nil)
        .where("created_at + expires_in * interval '1 second' > ?", Time.current).order(created_at: :desc)
      @remembered_sessions = remembered_sessions.joins(:access_tokens).distinct.where(revoked_at: nil)
        .where("mobile_remembered_sessions.expires_at > ?", Time.current).order(authorized_at: :desc)
    end

    def destroy
      token = tokens.find(params[:id])
      if token.remembered_session_id
        remembered_sessions.find(token.remembered_session_id).revoke!
      else
        token.revoke
      end
      redirect_to mobile_sessions_path, notice: "App connection disconnected.", status: :see_other
    end

    def destroy_remembered
      remembered_sessions.find_by!(public_id: params[:id]).revoke!
      redirect_to mobile_sessions_path, notice: "App connection disconnected.", status: :see_other
    end

    private

    def remembered_sessions
      RememberedSession.where(user_id: current_user.id)
    end

    def tokens
      Doorkeeper::AccessToken.where(resource_owner_id: current_user.id, scopes: "buddy_check")
    end
  end
end
