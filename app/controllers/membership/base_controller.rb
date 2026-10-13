module Membership
  class BaseController < ApplicationController
    before_action :require_authentication
    before_action :prevent_membership_caching
    before_action :load_workspace
    before_action :require_workspace_access

    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
    rescue_from MembershipWorkspace::AccessDenied, with: :access_denied
    rescue_from MembershipWorkspace::Conflict, ActiveRecord::StaleObjectError, ActiveRecord::RecordNotUnique, with: :entry_conflict
    rescue_from ArgumentError, ActionController::ParameterMissing, with: :invalid_request

    private

    def load_workspace
      @organization = Organization.first!
      @workspace = MembershipWorkspace.new(user: current_user, organization: @organization,
        membership_year: params[:membership_year].presence || MembershipWorkspace.initial_year(user: current_user, organization: @organization))
      @membership_year = @workspace.report.membership_year
      @access = @workspace.access
    end

    def require_workspace_access
      access_denied unless @access.permitted?
    end

    def require_membership_manager
      @workspace.require_manager!
    end

    def prevent_membership_caching
      response.cache_control.replace(no_store: true)
    end

    def load_member_context
      @person = @workspace.person(params[:person_id] || params[:id])
      @contacts = @workspace.contacts_for(@person)
      @contacts = @contacts.includes(:recorded_by, membership_assignment: { assigned_to: :person }).limit(50)
      @assignments = @access.assignments.where(person: @person).includes(:membership_drive, assigned_to: :person)
      @dues_records = @organization.membership_dues_records.where(person: @person, membership_year: @membership_year).includes(:recorded_by, :reversal).recent if @access.manager?
      @contact ||= MembershipContact.new(occurred_on: Organization.current_local_date,
        channel: "phone", purpose: "renewal", submission_key: SecureRandom.uuid)
      @contact.membership_assignment_id ||= params[:assignment_id]
      @contact.membership_assignment_id ||= @assignments.first&.id unless @access.manager?
      selected_assignment = @assignments.detect { |assignment| assignment.id == @contact.membership_assignment_id }
      @contact.purpose = selected_assignment.membership_drive.purpose if selected_assignment
      @buddy_task = @contact.purpose == "buddy_check"
      @assignments = @assignments.select { |assignment| (assignment.membership_drive.purpose == "buddy_check") == @buddy_task }
      if @buddy_task
        @contacts = @contacts.where(purpose: "buddy_check")
      elsif @access.manager?
        @contacts = @contacts.where.not(purpose: "buddy_check")
      end
      @contact_work_item = @workspace.contact_work_item(@person, purpose: @contact.purpose, assignment: selected_assignment)
      @dues_record ||= MembershipDuesRecord.new(kind: "post_receipt", received_on: Organization.current_local_date, submission_key: SecureRandom.uuid)
    end

    def load_worklist
      @work_filter = params[:filter] == "all" ? "all" : "attention"
      @people = @workspace.people
      if params[:q].present?
        query = params[:q].to_s.downcase
        @people = @people.select { |person| person.roster_display_name.downcase.include?(query) || person.full_name.downcase.include?(query) }
      end
      @work_items = @people.map { |person| [ person, @workspace.work_item(person) ] }
      @work_items.select! { |_person, item| item[:needs_attention] } if @work_filter == "attention"
      @work_items.sort_by! { |person, item| [ item[:priority], item[:follow_up_on] || Date.new(2101), person.last_name, person.first_name, person.id ] }
    end

    def load_post_checks
      @post_share_records = @organization.membership_dues_records.where(membership_year: @membership_year, kind: %w[post_share_received reversal], person_id: nil).includes(:recorded_by, :reversal).recent
      @dues_record ||= MembershipDuesRecord.new(kind: "post_share_received", received_on: Organization.current_local_date, submission_key: SecureRandom.uuid)
    end

    def access_denied(error = nil)
      @message = error&.message || "You do not have a current membership assignment or membership officer access."
      render "membership/error", status: :forbidden
    end

    def entry_conflict(error)
      @message = case error
      when ActiveRecord::StaleObjectError
        "This work changed while the page was open. Reload it before trying again."
      when ActiveRecord::RecordNotUnique
        "This entry or paper reference was already recorded. Reload and review the history."
      else
        error.message
      end
      render "membership/error", status: :conflict
    end

    def invalid_request(error)
      @message = error.message
      render "membership/error", status: :unprocessable_entity
    end
  end
end
