module Api
  class MembershipWorkController < BaseController
    prepend_before_action :prevent_private_data_caching
    authorize_with :authorize_workspace
    authorize_with :authorize_person, only: %i[person contact]
    authorize_with :authorize_contact_year, only: :contact
    authorize_with :authorize_contact_assignment, only: :contact

    rescue_from MembershipWorkspace::AccessDenied, with: ->(error) { render_error(error.message, status: :forbidden) }
    rescue_from MembershipWorkspace::Conflict, with: ->(error) { render_error(error.message, status: :conflict) }
    rescue_from ActiveRecord::RecordNotUnique, with: -> { render_error("This entry or paper reference was already recorded. Reload and review the history.", status: :conflict) }
    rescue_from ActiveRecord::RecordInvalid, with: ->(error) { render_error("The contact could not be saved.", status: :unprocessable_entity, details: error.record.errors.full_messages) }
    rescue_from ArgumentError, ActionController::ParameterMissing, with: ->(error) { render_error(error.message, status: :unprocessable_entity) }

    def index
      page = collection_page(@workspace.people)
      return if performed?

      render json: page[:metadata].merge(membership_year: @year, manager: @access.manager?,
        summary: @access.manager? ? @workspace.summary : nil,
        people: page[:records].map { |person| person_payload(person) },
        drives: @access.drives.where(membership_year: @year).order(created_at: :desc).map { |drive| drive_payload(drive) })
    end

    def person
      assignment = if params[:assignment_id].present?
        @access.assignments.where(person: @person).find(params[:assignment_id])
      end
      render json: {
        membership_year: @year, person: person_payload(@person, assignment:),
        assignments: @access.assignments.where(person: @person, revoked_at: nil).map { |assignment| assignment_payload(assignment) },
        contacts: @workspace.contacts_for(@person).limit(50).map { |contact| contact_payload(contact) }
      }
    end

    def contact
      attributes = contact_parameters.to_h.symbolize_keys.merge(person_id: @person.id)
      entry = @workspace.record_contact!(attributes)
      render json: { contact: contact_payload(entry) }, status: :created
    end

    def drive
      drive = permitted_drive
      render json: { drive: drive_payload(drive), assignments: @access.drive_assignments(drive).map { |assignment| assignment_payload(assignment) } }
    end

    def drive_print
      drive = permitted_drive
      pdf = MembershipPdf.render(organization:, user: current_user, drive:, caller_id: params[:caller_id])
      send_data pdf, filename: "membership-drive-#{drive.id}-#{drive.membership_year}.pdf", type: "application/pdf", disposition: "inline"
    rescue MembershipPdf::GenerationError
      render_error("The call sheet PDF could not be created. Try again.", status: :service_unavailable)
    end

    private

    def authorize_workspace
      @workspace = MembershipWorkspace.new(user: current_user, organization:,
        membership_year: params[:membership_year].presence || MembershipWorkspace.initial_year(user: current_user, organization:))
      @year = @workspace.report.membership_year
      @access = @workspace.access
      render_error("Current membership officer access or an active assignment is required.", status: :forbidden) unless @access.permitted?
    end

    def authorize_person
      @person = @workspace.person(params[:id])
    end

    def authorize_contact_year
      existing = @access.contacts.find_by(submission_key: contact_parameters[:submission_key])
      if existing && existing.membership_year != @year
        raise MembershipWorkspace::Conflict, "This submission belongs to another membership year. Use new submission and idempotency keys."
      end
    end

    def authorize_contact_assignment
      attributes = contact_parameters
      @workspace.check_contact_recording!(@person, attributes)
      @workspace.require_manager! if attributes[:outcome] == "contact_permission_restored" || attributes[:channel] == "administrative_review"
      id = attributes[:membership_assignment_id]
      if id.present?
        assignment = @access.assignments.find(id)
        raise MembershipWorkspace::AccessDenied, "The assignment does not belong to this member." unless assignment.person_id == @person.id
      elsif !@access.manager?
        raise MembershipWorkspace::AccessDenied, "Choose an active assignment."
      end
    end

    def contact_parameters
      params.expect(membership_contact: [ :membership_assignment_id, :purpose, :occurred_on, :channel, :outcome, :notes, :follow_up_on, :paper_reference, :submission_key ])
    end

    def person_payload(person, assignment: nil)
      work = if assignment
        @workspace.contact_work_item(person, purpose: assignment.membership_drive.purpose, assignment:)
      else
        @workspace.work_item(person)
      end
      purpose = work.fetch(:purpose)
      paused = @workspace.contact_paused?(person, purpose:)
      { id: person.id, name: person.roster_display_name, renewal_state: @workspace.report.renewal_state(person),
        work_state: @workspace.work_state(person), contact_purpose: purpose, contact_paused: paused,
        next_step: work[:next_step], needs_attention: work[:needs_attention], outreach_needed: work[:outreach_needed],
        phone_number: work[:outreach_needed] ? person.directory_phone_number : nil,
        email_address: work[:outreach_needed] ? person.directory_email_address : nil,
        roster_imported_at: person.roster_imported_at&.iso8601,
        last_contact: @workspace.last_contact(person)&.then { |contact| contact_payload(contact) } }
    end

    def drive_payload(drive)
      { id: drive.id, title: drive.title, purpose: drive.purpose, membership_year: drive.membership_year,
        starts_on: drive.starts_on, ends_on: drive.ends_on, closed_at: drive.closed_at, script: drive.script }
    end

    def permitted_drive
      drive = MembershipAccess.new(user: current_user, organization:).drives.find(params[:id])
      @workspace = MembershipWorkspace.new(user: current_user, organization:, membership_year: drive.membership_year)
      @year = drive.membership_year
      @access = @workspace.access
      drive
    end

    def assignment_payload(assignment)
      { id: assignment.id, membership_drive_id: assignment.membership_drive_id, person_id: assignment.person_id,
        assigned_to_id: assignment.assigned_to_id, expires_on: assignment.expires_on,
        revoked_at: assignment.revoked_at, lock_version: assignment.lock_version }
    end

    def contact_payload(contact)
      contact.attributes.slice("id", "person_id", "membership_assignment_id", "recorded_by_id", "membership_year",
        "purpose", "channel", "outcome", "occurred_on", "follow_up_on", "notes", "paper_reference", "created_at")
    end
  end
end
