class PasskeyInvitationsController < ApplicationController
  before_action :require_authentication

  def destroy
    session[:passkey_invite_dismissed] = true
    redirect_to root_path
  end
end
