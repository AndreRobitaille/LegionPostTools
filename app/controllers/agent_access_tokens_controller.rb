class AgentAccessTokensController < ApplicationController
  include TokenCreation

  EXPIRY_OPTIONS = { "30" => 30.days, "90" => 90.days, "180" => 180.days }.freeze

  before_action :require_authentication
  before_action :require_recent_token_authentication, only: :create
  before_action :set_agent_access_token, only: %i[revoke destroy]

  def index
    load_token_workspace
  end

  def new
    render_token_setup
  end

  def create
    @draft = creation_params.to_h
    expires_in = EXPIRY_OPTIONS[@draft["expires_in_days"]]
    unless expires_in
      @errors = [ "Choose an expiry of 30, 90, or 180 days." ]
      return render_token_setup(status: :unprocessable_entity)
    end

    @agent_access_token, @plaintext_token = issue_from_token_form(AgentAccessToken,
      user: current_user,
      name: @draft["name"],
      expires_in: expires_in
    )
    return redirect_to token_list_path, status: :see_other unless @plaintext_token
    clear_token_setup
    render :created, status: :created
  rescue ActiveRecord::RecordInvalid => e
    @errors = e.record.errors.full_messages
    render_token_setup(status: :unprocessable_entity)
  end

  def revoke
  end

  def destroy
    @agent_access_token.revoke!(current_user) unless @agent_access_token.revoked?
    redirect_to agent_access_tokens_path, notice: "Agent token revoked."
  end

  private

  def set_agent_access_token
    @agent_access_token = current_user.agent_access_tokens.find(params[:id])
  end
end
