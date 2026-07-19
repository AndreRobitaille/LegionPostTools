class DatedAgendasController < ApplicationController
  before_action :require_authentication
  before_action :set_organization
  before_action :set_dated_agenda, only: %i[show print]

  def index
    @dated_agendas = @organization.dated_agendas.published.upcoming.includes(:meeting_body).order(:starts_at, :title)
  end

  def show; end

  def print
    render layout: "print"
  end

  private

  def set_organization
    @organization = Organization.first!
  end

  def set_dated_agenda
    @dated_agenda = @organization.dated_agendas.published.find(params[:id])
  end
end
