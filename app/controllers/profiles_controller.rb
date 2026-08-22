# Self-service account controls for the signed-in member: how they sign in, and
# (later) their photo. Distinct from PeopleController#show, which is the post's
# record of a person — roster data, login-account administration, post roles.
class ProfilesController < ApplicationController
  before_action :require_authentication

  def show
    @person = current_user.person
    @passkey_credentials = current_user.passkey_credentials.order(:created_at)
  end
end
