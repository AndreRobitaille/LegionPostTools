module BuddyChecks
  class ContactsController < BaseController
    rescue_from ArgumentError, KeyError, ActionController::ParameterMissing, ActiveRecord::RecordInvalid,
      BuddyChecks::Conflict, ActiveRecord::StaleObjectError, with: :invalid_entry

    def index
      @page = params.fetch(:page, 1).to_i.clamp(1, 10_000)
      @contacts = @access.owned_contacts.effective.includes(:person, :membership_assignment).recent.limit(26).offset((@page - 1) * 25).to_a
      @more = @contacts.size > 25
      @contacts = @contacts.first(25)
    end

    def new
      @person = @access.person!(params[:person_id])
      load_assignments
      @form = { operation_id: SecureRandom.uuid, occurred_at: local_now, channel: "phone", outcome: "reached", assignment_id: @assignments.first&.id }.with_indifferent_access
    end

    def create
      load_submission
      @operations.record(operation_id: @form.fetch("operation_id"), person_id: @person.id, facts: facts, assignment_id: @form["assignment_id"],
        follow_up: @form["due_at"].present? ? { due_at: local_instant(@form["due_at"]), entry_zone: entry_zone } : nil)
      redirect_to buddy_checks_person_path(@person), notice: "Buddy Check recorded.", status: :see_other
    end

    def edit
      load_contact
      @form = { operation_id: SecureRandom.uuid, expected_revision: @contact.revision, channel: @contact.channel,
        outcome: @contact.outcome, notes: @contact.notes, occurred_on: @contact.occurred_on.iso8601,
        occurred_at: @contact.occurred_at&.in_time_zone(@organization.calendar_time_zone)&.strftime("%Y-%m-%dT%H:%M") }.with_indifferent_access
    end

    def update
      load_contact
      load_submission
      @operations.correct(operation_id: @form.fetch("operation_id"), id: @contact.id,
        expected_revision: @form.fetch("expected_revision"), facts: facts)
      redirect_to buddy_checks_contacts_path, notice: "Correction saved. The original check is preserved.", status: :see_other
    end

    private

    def load_contact
      original = @access.owned_contacts.find(params[:id])
      root_id = original.logical_contact_id || original.id
      @contact = @access.owned_contacts.effective.where("id = :id OR logical_contact_id = :id", id: root_id).sole
      @person = @access.person!(@contact.person_id)
    end

    def load_submission
      @form = params.require(:buddy_check).permit(:operation_id, :person_id, :assignment_id, :expected_revision, :channel, :outcome, :occurred_at, :occurred_on, :notes, :due_at).to_h
      @person ||= @access.person!(@form.fetch("person_id"))
      load_assignments unless @contact
    end

    def load_assignments
      @assignments = @access.assignments.where(person: @person).includes(:membership_drive).order(:id)
    end

    def facts
      result = @form.slice("channel", "outcome", "notes")
      if @contact && @contact.occurred_at.nil?
        result.merge(occurred_on: @form.fetch("occurred_on"))
      else
        result.merge(occurred_at: local_instant(@form.fetch("occurred_at")), entry_zone: entry_zone)
      end
    end

    def invalid_entry(error)
      @error = form_error(error)
      return render("buddy_checks/denied", status: :unprocessable_entity) unless @person && @form
      render(action_name == "update" ? :edit : :new, status: error.is_a?(BuddyChecks::Conflict) ? :conflict : :unprocessable_entity)
    end
  end
end
