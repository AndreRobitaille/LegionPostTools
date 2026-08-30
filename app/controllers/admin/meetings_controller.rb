module Admin
  class MeetingsController < ApplicationController
    before_action -> { require_capability("manage_agendas") }
    before_action :set_organization
    before_action :set_meeting, only: %i[show edit update destroy create_agenda]
    before_action :set_form_collections, only: %i[new create edit update]

    def index
      @upcoming_meetings = @organization.meetings.upcoming.includes(:meeting_body, :meeting_type, :dated_agenda)
      @past_meetings = @organization.meetings.past.includes(:meeting_body, :meeting_type, :dated_agenda)
    end

    def show; end

    def new
      first_body = @organization.meeting_bodies.order(:name).first
      @meeting = @organization.meetings.new(
        meeting_body: first_body,
        starts_at: default_starts_at,
        location_name: first_body&.effective_location_name,
        location_address: first_body&.effective_location_address
      )
    end

    def create
      @meeting = @organization.meetings.new(meeting_params)
      if @meeting.save
        redirect_to admin_meeting_path(@meeting), notice: "Meeting created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @meeting.update_with_agenda_sync(meeting_params)
        redirect_to admin_meeting_path(@meeting), notice: "Meeting details saved."
      else
        render :edit, status: :unprocessable_entity
      end
    rescue ActiveRecord::StaleObjectError
      redirect_to edit_admin_meeting_path(@meeting), alert: "This meeting was changed by someone else. Review the latest version before saving."
    end

    def destroy
      unless @meeting.empty_record?
        return redirect_to admin_meeting_path(@meeting), alert: "Remove the meeting's agenda before deleting the meeting."
      end

      @meeting.destroy!
      redirect_to admin_meetings_path, notice: "Meeting deleted.", status: :see_other
    rescue ActiveRecord::DeleteRestrictionError, ActiveRecord::RecordNotDestroyed
      redirect_to admin_meeting_path(@meeting), alert: "This meeting has historical records and cannot be deleted."
    end

    def create_agenda
      if @meeting.dated_agenda
        return redirect_to edit_admin_dated_agenda_path(@meeting.dated_agenda)
      end

      agenda = DatedAgenda.create_from_template!(meeting: @meeting)
      redirect_to edit_admin_dated_agenda_path(agenda), notice: "Agenda prepared from the meeting type."
    rescue ActiveRecord::RecordInvalid => error
      message = error.record.errors.full_messages.to_sentence.presence || "Choose a meeting type before preparing the agenda."
      redirect_to edit_admin_meeting_path(@meeting), alert: message
    end

    private

    def set_organization
      @organization = Organization.first!
    end

    def set_meeting
      @meeting = @organization.meetings.includes(:dated_agenda).find(params[:id])
    end

    def set_form_collections
      @meeting_bodies = @organization.meeting_bodies.order(:name)
      @meeting_types = @organization.meeting_types.active.ordered
      @meeting_body_locations = @meeting_bodies.to_h do |body|
        [ body.id, { name: body.effective_location_name, address: body.effective_location_address } ]
      end
    end

    def meeting_params
      permitted = params.require(:meeting).permit(
        :meeting_body_id,
        :meeting_type_id,
        :starts_at,
        :starts_at_date,
        :starts_at_time,
        :title,
        :location_name,
        :location_address,
        :lock_version
      )

      if permitted.key?(:starts_at_date)
        permitted[:starts_at] = helpers.combine_legion_datetime(
          permitted.delete(:starts_at_date),
          permitted.delete(:starts_at_time)
        )
      end

      permitted
    end

    def default_starts_at
      Time.zone.now.change(hour: 19, min: 0) + 1.week
    end
  end
end
