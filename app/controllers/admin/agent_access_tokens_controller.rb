module Admin
  class AgentAccessTokensController < BaseController
    before_action :set_agent_access_token, only: %i[revoke destroy]

    def index
      @agent_access_tokens = AgentAccessToken.includes(user: :person).newest_first
    end

    def revoke
    end

    def destroy
      @agent_access_token.revoke!(current_user) unless @agent_access_token.revoked?
      redirect_to admin_agent_access_tokens_path, notice: "Agent token revoked."
    end

    private

    def set_agent_access_token
      @agent_access_token = AgentAccessToken.find(params[:id])
    end
  end
end
