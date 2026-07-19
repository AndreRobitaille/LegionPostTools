module Admin
  class DatedAgendasController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_dated_agenda, only: %i[edit update approve publish reopen print]
    before_action :set_form_collections, only: %i[new create edit update]

    def index
      @dated_agendas = @organization.dated_agendas.includes(:meeting_body, :meeting_type).ordered
    end

    def new
      @dated_agenda = @organization.dated_agendas.new(starts_at: default_starts_at, status: "draft")
    end

    def create
      dated_agenda = dated_agenda_params
      meeting_body = @organization.meeting_bodies.find(dated_agenda[:meeting_body_id])
      meeting_type = @organization.meeting_types.active.find(dated_agenda[:meeting_type_id])
      starts_at = Time.zone.parse(dated_agenda[:starts_at].to_s)
      raise ArgumentError, "Starts at can't be blank" if starts_at.blank?
      title = dated_agenda[:title]
      @dated_agenda = DatedAgenda.create_from_template!(organization: @organization, meeting_body:, meeting_type:, starts_at:, title: title)
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Dated agenda created."
    rescue ActiveRecord::RecordNotFound
      raise
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      @dated_agenda = @organization.dated_agendas.new(dated_agenda_params.merge(status: "draft"))
      message = e.respond_to?(:record) ? e.record&.errors&.full_messages&.to_sentence : e.message
      @dated_agenda.errors.add(:base, message)
      set_form_collections
      render :new, status: :unprocessable_entity
    end

    def edit; end

    def update
      if @dated_agenda.locked_for_editing?
        redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "Reopen this agenda before editing."
      elsif @dated_agenda.update(dated_agenda_params.except(:meeting_body_id, :meeting_type_id))
        redirect_to edit_admin_dated_agenda_path(@dated_agenda), notice: "Dated agenda updated."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_dated_agenda_path(@dated_agenda), alert: "This agenda was changed by someone else. Review the latest version before saving."
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
      render layout: "print"
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_dated_agenda
      @dated_agenda = @organization.dated_agendas.find(params[:id])
    end

    def set_form_collections
      @meeting_bodies = @organization.meeting_bodies.order(:name)
      @meeting_types = @organization.meeting_types.active.ordered
    end

    def dated_agenda_params
      params.require(:dated_agenda).permit(:meeting_body_id, :meeting_type_id, :starts_at, :title, :lock_version)
    end

    def default_starts_at
      Time.zone.now.change(hour: 19, min: 0) + 1.week
    end
  end
end
