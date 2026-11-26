class PasskeyInvitationsController < ApplicationController
  include PasskeyEnrollment

  before_action :require_authentication

  def destroy
    clear_passkey_enrollment if pending_passkey_enrollment&.dig("source") == "dashboard"
    session[:passkey_invite_dismissed] = true
    redirect_to root_path
  end
end
