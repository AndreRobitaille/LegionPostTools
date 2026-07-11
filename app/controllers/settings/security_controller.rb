class Settings::SecurityController < ApplicationController
  before_action :require_authentication

  def show
    @passkey_credentials = current_user.passkey_credentials.order(:created_at)
  end
end
