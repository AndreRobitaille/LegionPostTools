class DatedAgendasController < ApplicationController
  before_action :require_authentication
  before_action :set_organization
  before_action :set_dated_agenda, only: %i[show print]

  def index
    @dated_agendas = @organization.dated_agendas.published.upcoming.includes(:meeting_body).order(:starts_at, :title)
  end

  def show; end

  def print
    send_agenda_pdf("agenda")
  end

  private

  def set_organization
    @organization = Organization.first!
  end

  def set_dated_agenda
    @dated_agenda = @organization.dated_agendas.published.find(params[:id])
  end

  def send_agenda_pdf(variant)
    pdf = DatedAgendaPdf.render(dated_agenda: @dated_agenda, variant:)
    send_data pdf,
      filename: DatedAgendaPdf.filename(dated_agenda: @dated_agenda, variant:),
      type: "application/pdf",
      disposition: "inline"
    no_store
  rescue DatedAgendaPdf::GenerationError => error
    Rails.logger.error("Agenda PDF generation failed: #{error.message}")
    redirect_to dated_agenda_path(@dated_agenda), alert: "The agenda PDF could not be created. Try again."
  end
end
