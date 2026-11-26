module MinutesActionIdentity
  extend ActiveSupport::Concern

  PURPOSE = "official_minutes_action"
  SESSION_KEY = :minutes_action_identity

  included do
    rate_limit to: 20, within: 5.minutes, only: :create, scope: "minutes_passkey_options",
      if: :starting_minutes_passkey?, with: -> { head :too_many_requests }
    rate_limit to: 5, within: 5.minutes, only: :create, scope: "minutes_identity_email",
      unless: :starting_minutes_passkey?,
      by: -> { "#{current_user.id}:#{request.remote_ip}" },
      with: -> { redirect_back fallback_location: officer_tools_path, alert: "Please wait a few minutes before requesting another code." }
  end

  private

  def starting_minutes_passkey? = params[:identity_method] == "passkey"

  def begin_minutes_confirmation(action, payload = {})
    @confirmation = prepare_reviewed_confirmation(action, payload)
    unless @confirmation
      message = "The minutes changed. Review the current copy and start again."
      return render json: { error: message }, status: :conflict if request.format.json?
      return redirect_to admin_meeting_minutes_path(@meeting), alert: message
    end
    session[SESSION_KEY] = { "id" => @confirmation.id, "origin" => params[:origin] == "meeting" ? "meeting" : "workspace" }

    if starting_minutes_passkey?
      options = WebAuthn::Credential.options_for_get(allow: current_user.passkey_credentials.pluck(:external_id), user_verification: "required")
      session[SESSION_KEY]["passkey_challenge"] = options.challenge
      render json: { options:, confirmation_id: @confirmation.id, verify_url: passkey_official_action_reauthentication_path }
    else
      send_minutes_code
    end
  end

  def prepare_reviewed_confirmation(action, payload)
    @minutes.with_lock do
      confirmation = OfficialActionConfirmation.prepare!(minutes: @minutes, user: current_user, session: Current.session,
        action:, action_payload: payload)
      # The review page knows the revision before the officer fills in the decision or reason.
      digest = payload.empty? ? confirmation.content_digest : @minutes.digest_for(action)
      unless params[:reviewed_digest] == digest && params[:reviewed_version] == confirmation.record_lock_version.to_s
        raise ActiveRecord::Rollback
      end

      confirmation
    end
  end

  def send_minutes_code
    challenge = MagicLink.create_for!(current_user, purpose: PURPOSE, session: Current.session)
    MailDelivery.deliver_magic_link(
      user: current_user,
      login_url: magic_link_official_action_reauthentication_url(confirmation_id: @confirmation.id, token: challenge.token),
      login_code: MagicLink.format_code(challenge.login_code)
    )
    session[SESSION_KEY]["email_selector"] = challenge.browser_challenge
    redirect_to minutes_identity_path(pending: true), status: :see_other
  rescue MailDelivery::DeliveryError => error
    Rails.logger.error("Minutes confirmation email delivery failed status=#{error.status || 'unavailable'}")
    redirect_to minutes_identity_path(pending: true), status: :see_other, alert: "We couldn't send the email. Try sending a new code."
  end

  def minutes_identity_path(pending: false)
    meeting = @confirmation.meeting_minutes.meeting
    options = pending ? { confirmation_id: @confirmation.id, anchor: "minutes-signing" } : {}
    case @confirmation.action
    when "reopen" then new_admin_meeting_minutes_reopening_path(meeting, options)
    when "record_membership_approval" then new_admin_meeting_minutes_membership_approval_path(meeting, options)
    else
      if session[SESSION_KEY]["origin"] == "meeting"
        admin_meeting_path(meeting, options)
      else
        admin_meeting_minutes_path(meeting, options)
      end
    end
  end
end
