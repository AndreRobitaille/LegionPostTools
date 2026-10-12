module Membership
  class BuddyAttendanceController < BaseController
    before_action :require_membership_manager
    before_action -> { head :forbidden unless current_user.mobile_buddy_checks_access? }

    def index
      @meetings = @organization.meetings.where("starts_at <= ?", Time.current).ordered.limit(100)
    end

    def show
      load_register
    end

    def create
      load_register
      BuddyAttendanceRegister.record!(meeting: @meeting, user: current_user, expected_revision: params.require(:expected_revision),
        entries: params.require(:entries).permit(*@entries.keys).to_h, complete: params[:complete] == "1", coverage_note: params[:coverage_note])
      redirect_to membership_buddy_attendance_path(@meeting), notice: "General-member attendance saved. Minutes are unchanged.", status: :see_other
    rescue BuddyChecks::Conflict
      @message = "Attendance changed while you were reviewing it. Reload and review the current coverage."
      render "membership/error", status: :conflict
    rescue BuddyChecks::Denied
      head :forbidden
    rescue ActiveRecord::RecordInvalid => error
      load_register
      @entries = error.record.entries
      @coverage_note = error.record.coverage_note
      @complete = error.record.complete?
      flash.now[:alert] = error.record.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end

    private

    def load_register
      @meeting = @organization.meetings.find(params[:id])
      @register = BuddyAttendanceRegister.where(meeting: @meeting).order(revision: :desc).first
      @entries = @register&.entries || Person.roster_backed.directory_visible.order(:last_name, :first_name).pluck(:id).to_h { |id| [ id.to_s, "not_recorded" ] }
      @people = Person.where(id: @entries.keys).order(:last_name, :first_name)
      @coverage_note = @register&.coverage_note
      @complete = @register&.complete?
    end
  end
end
