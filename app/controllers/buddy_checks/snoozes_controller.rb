module BuddyChecks
  class SnoozesController < BaseController
    def index
      @snoozes = @access.snoozes.where(cancelled_at: nil).where("until_at > ?", Time.current).includes(:person).order(:until_at)
    end

    def create
      @person = @access.person!(params.require(:person_id))
      @operations.snooze(operation_id: params.require(:operation_id), person_id: @person.id, until_at: 7.days.from_now.iso8601)
      redirect_to buddy_checks_root_path, notice: "Suggestion deferred for seven days.", status: :see_other
    end

    def destroy
      snooze = @access.snoozes.find(params[:id])
      @operations.undo_snooze(id: snooze.id, operation_id: params.require(:operation_id), expected_revision: params.require(:expected_revision))
      redirect_to buddy_checks_snoozes_path, notice: "Suggestion restored.", status: :see_other
    rescue BuddyChecks::Conflict, ActiveRecord::StaleObjectError => error
      @error = form_error(error)
      index
      render :index, status: :conflict
    end
  end
end
