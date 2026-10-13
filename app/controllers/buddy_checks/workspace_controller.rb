module BuddyChecks
  class WorkspaceController < BaseController
    skip_before_action :load_buddy_workspace, only: :index

    def index
      unless current_user.mobile_buddy_checks_access?
        return redirect_to buddy_checks_activity_path if current_user.buddy_check_coordination_access?
        return head :forbidden
      end
      load_buddy_workspace
      @suggestion = suggestions.suggest
      @due_follow_ups = @access.follow_ups.where(status: "open").where("due_at <= ?", Time.current).includes(:person).order(:due_at).limit(5)
    end

    def people
      load_people
    rescue ArgumentError
      @people = @access.people.none
      @search_error = "Enter a member name between 2 and 80 characters."
      render :people, status: :unprocessable_entity
    end

    def show
      @person = @access.person!(params[:id])
      @eligibility = suggestions.eligibility(@person)
      @attendance_evidence = suggestions.absence_evidence(@person)
      @contacts = @access.owned_contacts.effective.where(person: @person).recent.limit(10)
      @follow_ups = @access.follow_ups.where(person: @person, status: "open").order(:due_at)
      @snooze = @access.snoozes.where(person: @person, cancelled_at: nil).where("until_at > ?", Time.current).order(:until_at).first
    end

    private

    def load_people
      scope = @access.people.where.not(id: current_user.person_id)
      scope = BuddyChecks::PeopleSearch.new(scope).call(params[:q]) if params[:q].present?
      @people = scope.order(:last_name, :first_name, :id).limit(50)
    end
  end
end
