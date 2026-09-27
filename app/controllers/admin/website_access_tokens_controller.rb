module Admin
  class WebsiteAccessTokensController < BaseController
    before_action :prevent_credential_caching
    before_action :require_recent_authentication, only: %i[new create]
    before_action :set_website_access_token, only: %i[revoke destroy]

    def index
      @organization = Organization.first!
      @website_access_tokens = @organization.website_access_tokens.includes(created_by: :person, revoked_by: :person).newest_first
    end

    def new
      @website_access_token = Organization.first!.website_access_tokens.new
    end

    def create
      @website_access_token, @plaintext_token = WebsiteAccessToken.issue!(
        organization: Organization.first!, actor: current_user,
        name: params.require(:website_access_token).permit(:name)[:name].to_s
      )
      render :created, status: :created
    rescue ActiveRecord::RecordInvalid => error
      @website_access_token = error.record
      render :new, status: :unprocessable_entity
    end

    def revoke
    end

    def destroy
      @website_access_token.revoke!(current_user)
      redirect_to admin_website_access_tokens_path, notice: "Website token revoked."
    end

    private

    def require_recent_authentication
      if Current.session&.recently_authenticated?
        session.delete(:website_token_reauthentication)
        return
      end

      session[:website_token_reauthentication] = true
      redirect_to new_agent_access_reauthentication_path,
        alert: "Confirm your identity before creating a website token."
    end

    def set_website_access_token
      @website_access_token = Organization.first!.website_access_tokens.find(params[:id])
    end

    def prevent_credential_caching
      response.headers["Cache-Control"] = "no-store"
    end
  end
end
