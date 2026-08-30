module Admin
  class DatedAgendasController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_dated_agenda, only: %i[edit destroy approve publish reopen print commander]

    def index
      redirect_to admin_meetings_path
    end

    def edit
      @agenda_sections = agenda_sections_with_content
    end

    def destroy
      meeting = @dated_agenda.meeting
      @dated_agenda.destroy!
      redirect_to admin_meeting_path(meeting), notice: "Dated agenda deleted. The meeting remains in the record.", status: :see_other
    end

    def approve
      @dated_agenda.approve!(current_user)
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Dated agenda approved."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: @dated_agenda.errors.full_messages.to_sentence.presence || "Could not approve this agenda."
    end

    def publish
      @dated_agenda.publish!(current_user)
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Dated agenda published."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: @dated_agenda.errors.full_messages.to_sentence.presence || "Could not publish this agenda."
    end

    def reopen
      @dated_agenda.reopen!(current_user)
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Dated agenda reopened."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::StaleObjectError
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: @dated_agenda.errors.full_messages.to_sentence.presence || "Could not reopen this agenda."
    end

    def print
      send_agenda_pdf("agenda")
    end

    def commander
      send_agenda_pdf("officer_notes")
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_dated_agenda
      @dated_agenda = @organization.dated_agendas.find(params[:id])
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
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "The PDF could not be created. Try again."
    end

    def agenda_sections_with_content
      @dated_agenda.dated_agenda_sections.ordered.includes(
        agenda_items: [ :agenda_item_catalog_entry, :rich_text_body, :rich_text_commander_notes, :roll_call_entries ]
      )
    end
  end
end
