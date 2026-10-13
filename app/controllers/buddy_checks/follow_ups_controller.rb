module BuddyChecks
  class FollowUpsController < BaseController
    rescue_from ArgumentError, KeyError, ActionController::ParameterMissing, ActiveRecord::RecordInvalid,
      BuddyChecks::Conflict, ActiveRecord::StaleObjectError, with: :invalid_entry

    def index
      @follow_ups = @access.follow_ups.where(status: "open").includes(:person).order(:due_at)
      @legacy_callbacks = @access.owned_contacts.effective.where.not(follow_up_on: nil).includes(:person).recent.limit(25)
    end

    def new
      @person = @access.person!(params[:person_id])
      @form = { operation_id: SecureRandom.uuid, due_at: 1.day.from_now.in_time_zone(@organization.calendar_time_zone).strftime("%Y-%m-%dT%H:%M") }.with_indifferent_access
    end

    def create
      load_submission
      @person = @access.person!(@form.fetch("person_id"))
      @operations.schedule(operation_id: @form.fetch("operation_id"), person_id: @person.id,
        due_at: local_instant(@form.fetch("due_at")), entry_zone: entry_zone)
      redirect_to buddy_checks_follow_ups_path, notice: "Callback scheduled.", status: :see_other
    end

    def edit
      load_follow_up
      @form = { operation_id: SecureRandom.uuid, expected_revision: @follow_up.lock_version,
        due_at: @follow_up.due_at.in_time_zone(@organization.calendar_time_zone).strftime("%Y-%m-%dT%H:%M") }.with_indifferent_access
    end

    def update
      load_follow_up
      load_submission
      action = @form.fetch("change")
      @operations.change_follow_up(operation_id: @form.fetch("operation_id"), id: @follow_up.id,
        expected_revision: @form.fetch("expected_revision"), action:,
        due_at: action == "reschedule" ? local_instant(@form.fetch("due_at")) : nil,
        entry_zone: action == "reschedule" ? entry_zone : nil)
      redirect_to buddy_checks_follow_ups_path, notice: { "reschedule" => "Callback rescheduled.", "complete" => "Callback marked complete.", "cancel" => "Callback cancelled." }.fetch(action), status: :see_other
    end

    private

    def load_follow_up
      @follow_up = @access.follow_ups.find(params[:id])
      @person = @access.person!(@follow_up.person_id)
    end

    def load_submission
      @form = params.require(:callback).permit(:operation_id, :person_id, :expected_revision, :change, :due_at).to_h
    end

    def invalid_entry(error)
      @error = form_error(error)
      return render("buddy_checks/denied", status: :unprocessable_entity) unless @person && @form
      render(action_name == "update" ? :edit : :new, status: error.is_a?(BuddyChecks::Conflict) ? :conflict : :unprocessable_entity)
    end
  end
end
