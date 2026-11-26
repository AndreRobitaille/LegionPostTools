class OfficialActionReauthenticationsController < ApplicationController
  before_action :require_authentication
  before_action :set_confirmation
  include MinutesActionIdentity
  include PasskeyAssertion

  rate_limit to: 20, within: 5.minutes, only: :passkey, with: -> { head :too_many_requests }

  def new
    redirect_to minutes_identity_path(pending: true)
  end

  def create
    send_minutes_code
  end

  def verify
    user = MagicLink.consume_code!(browser_challenge: identity["email_selector"], code: params[:code],
      purpose: PURPOSE, session: Current.session)
    return complete_action if user == current_user

    redirect_to minutes_identity_path(pending: true), alert: "Check the code or send a new one."
  end

  def magic_link
    return render :magic_link if request.get? || request.head?

    selector = identity["email_selector"]
    user = MagicLink.consume!(params[:token], purpose: PURPOSE, session: Current.session,
      browser_challenge_digest: MagicLink.digest(selector)) if selector.present?
    return complete_action if user == current_user

    redirect_to minutes_identity_path(pending: true), alert: "That link has expired or was replaced. Send a new code."
  end

  def passkey
    challenge = identity.delete("passkey_challenge")
    return head :unprocessable_entity if challenge.blank?

    assertion = WebAuthn::Credential.from_get(public_key_credential_params)
    stored = current_user.passkey_credentials.find_by(external_id: assertion.id)
    return head :unauthorized unless stored

    verify_passkey_assertion!(assertion, stored, challenge)
    complete_action
  rescue WebAuthn::Error
    head :unprocessable_entity
  end

  def destroy
    @confirmation.with_lock { @confirmation.update!(expires_at: Time.current) unless @confirmation.consumed_at? }
    destination = minutes_identity_path
    session.delete(SESSION_KEY)
    redirect_to destination, status: :see_other, notice: "Confirmation cancelled."
  end

  private

  # A POST to create here always resends an email.
  def starting_minutes_passkey? = false

  def identity
    session[SESSION_KEY] || {}
  end

  def set_confirmation
    @confirmation = current_user.official_action_confirmations.find_by(id: params[:confirmation_id], session: Current.session)
    return if @confirmation && @confirmation.id == identity["id"] && @confirmation.usable_by?(user: current_user, session: Current.session)

    destination = @confirmation ? admin_meeting_minutes_path(@confirmation.meeting_minutes.meeting) : officer_tools_path
    finish_request(destination, alert: "This request has ended. Review the minutes and start again.")
  end

  def complete_action
    notice = @confirmation.transaction do
      @confirmation.confirm!(session: Current.session)
      @confirmation.complete_minutes_action!
    end
    Current.session.reauthenticate!
    session.delete(SESSION_KEY)
    finish_request(admin_meeting_minutes_path(@confirmation.meeting_minutes.meeting), notice:)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
    session.delete(SESSION_KEY)
    finish_request(admin_meeting_minutes_path(@confirmation.meeting_minutes.meeting),
      alert: "The minutes or your permission changed. Review the minutes and start again.")
  end

  def finish_request(destination, **message)
    if request.format.json?
      flash.update(message)
      render json: { redirect_url: destination }
    else
      redirect_to destination, status: :see_other, **message
    end
  end
end
