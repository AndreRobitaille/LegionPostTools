class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    @organization = Organization.first
    @show_passkey_invite =
      current_user.passkey_credentials.empty? && !session[:passkey_invite_dismissed]
  end
end
