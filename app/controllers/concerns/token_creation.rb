module TokenCreation
  extend ActiveSupport::Concern

  included do
    before_action :no_store
    helper_method :website_connection?, :token_setup, :token_list_path, :token_kind, :new_token_form_id
  end

  private

  def website_connection? = false
  def token_kind = website_connection? ? "website" : "agent"
  def token_list_path = website_connection? ? admin_website_access_tokens_path : agent_access_tokens_path
  def token_creation_path = website_connection? ? new_admin_website_access_token_path : new_agent_access_token_path
  def token_setup_key = website_connection? ? :website_token_setup : :agent_token_setup
  def token_setup = session[token_setup_key] ||= {}
  def clear_token_setup = session.delete(token_setup_key)

  def token_form_verifier = Rails.application.message_verifier(:token_issuance)
  def token_form_purpose = "#{Current.session.id}:#{token_kind}"

  def new_token_form_id
    token_form_verifier.generate(SecureRandom.hex(12), purpose: token_form_purpose)
  end

  # A browser may repeat its final POST when reloading the one-time reveal.
  # The form's public ID lets a repeat return to the list without issuing again.
  def issue_from_token_form(model, **attributes)
    return model.issue!(**attributes) unless params[:form_id]

    public_id = token_form_verifier.verified(params[:form_id], purpose: token_form_purpose)
    return unless public_id

    Current.session.with_lock do
      model.issue!(**attributes, public_id:) unless model.exists?(public_id:)
    end
  end

  def creation_params
    if website_connection?
      params.require(:website_access_token).permit(:name)
    else
      params.require(:agent_access_token).permit(:name, :expires_in_days)
    end
  end

  def require_recent_token_authentication
    return if Current.session.recently_authenticated?

    # Limit cookie size, keeping an overlong name invalid until it is edited.
    draft = { "name" => creation_params[:name].to_s.first(81) }
    unless website_connection?
      draft["expires_in_days"] = creation_params[:expires_in_days].presence_in(AgentAccessTokensController::EXPIRY_OPTIONS.keys)
    end
    token_setup["draft"] = draft
    redirect_to token_creation_path, status: :see_other
  end

  def load_token_workspace
    if website_connection?
      @organization = Organization.first!
      @website_access_tokens = @organization.website_access_tokens.includes(created_by: :person, revoked_by: :person).newest_first
    else
      @agent_access_tokens = current_user.agent_access_tokens.newest_first
      @agent_operator_instructions = AgentOperatorInstructions.new(
        user: current_user, organization: Organization.first!, base_url: request.base_url
      ).to_s
    end
  end

  def render_token_setup(status: :ok, email_link: false)
    @creating = true
    @email_link = email_link
    load_token_workspace
    render website_connection? ? "admin/website_access_tokens/index" : "agent_access_tokens/index", status: status
  end
end
