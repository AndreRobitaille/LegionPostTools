class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    @organization = Organization.first
  end
end
