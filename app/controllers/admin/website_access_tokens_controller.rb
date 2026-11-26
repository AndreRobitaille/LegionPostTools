module Admin
  class WebsiteAccessTokensController < BaseController
    include TokenCreation

    before_action :require_recent_token_authentication, only: :create
    before_action :set_website_access_token, only: %i[revoke destroy]

    def index
      load_token_workspace
    end

    def new
      render_token_setup
    end

    def create
      @draft = creation_params.to_h
      @website_access_token, @plaintext_token = issue_from_token_form(WebsiteAccessToken,
        organization: Organization.first!, actor: current_user,
        name: @draft["name"]
      )
      return redirect_to token_list_path, status: :see_other unless @plaintext_token
      clear_token_setup
      render :created, status: :created
    rescue ActiveRecord::RecordInvalid => error
      @errors = error.record.errors.full_messages
      render_token_setup(status: :unprocessable_entity)
    end

    def revoke
    end

    def destroy
      @website_access_token.revoke!(current_user)
      redirect_to admin_website_access_tokens_path, notice: "Website token revoked."
    end

    private

    def website_connection? = true

    def set_website_access_token
      @website_access_token = Organization.first!.website_access_tokens.find(params[:id])
    end
  end
end
