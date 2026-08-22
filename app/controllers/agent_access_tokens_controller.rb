class AgentAccessTokensController < ApplicationController
  EXPIRY_OPTIONS = { "30" => 30.days, "90" => 90.days, "180" => 180.days }.freeze

  before_action :require_authentication
  before_action :require_recent_authentication, only: %i[new create]
  before_action :set_agent_access_token, only: %i[revoke destroy]
  after_action :prevent_credential_caching, only: :create

  def index
    @agent_access_tokens = current_user.agent_access_tokens.newest_first
  end

  def new
    @agent_access_token = current_user.agent_access_tokens.new
  end

  def create
    @agent_access_token = current_user.agent_access_tokens.new(name: token_params[:name].to_s.strip)
    expires_in = EXPIRY_OPTIONS[token_params[:expires_in_days]]
    unless expires_in
      @agent_access_token.errors.add(:expires_at, "must be 30, 90, or 180 days")
      return render :new, status: :unprocessable_entity
    end

    @agent_access_token, @plaintext_token = AgentAccessToken.issue!(
      user: current_user,
      name: token_params[:name],
      expires_in: expires_in
    )
    render :created, status: :created
    response.cache_control.replace(no_store: true)
  rescue ActiveRecord::RecordInvalid => e
    @agent_access_token = e.record
    render :new, status: :unprocessable_entity
  end

  def revoke
  end

  def destroy
    @agent_access_token.revoke!(current_user) unless @agent_access_token.revoked?
    redirect_to agent_access_tokens_path, notice: "Agent token revoked."
  end

  private

  def require_recent_authentication
    return if Current.session&.recently_authenticated?

    redirect_to new_agent_access_reauthentication_path,
      alert: "Confirm your identity before creating an agent token."
  end

  def set_agent_access_token
    @agent_access_token = current_user.agent_access_tokens.find(params[:id])
  end

  def token_params
    params.require(:agent_access_token).permit(:name, :expires_in_days)
  end

  def prevent_credential_caching
    response.headers["Cache-Control"] = "no-store"
  end
end
