module Membership
  class ContactsController < BaseController
    def new
      load_member_context
    end

    def create
      attributes = params.expect(membership_contact: [ :membership_assignment_id, :purpose, :occurred_on, :channel, :outcome, :notes, :follow_up_on, :paper_reference, :submission_key ]).to_h.symbolize_keys
      entry = @workspace.record_contact!(attributes.merge(person_id: params[:person_id]))
      notice = entry.channel == "administrative_review" ? "Review recorded." : "Contact recorded."
      destination = if entry.purpose == "buddy_check" && current_user.buddy_check_coordination_access?
        buddy_checks_member_history_path(entry.person)
      else
        membership_person_path(params[:person_id], membership_year: @membership_year, assignment_id: entry.membership_assignment_id)
      end
      redirect_to destination, notice:, status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @contact = error.record
      load_member_context
      render :new, status: :unprocessable_entity
    end
  end
end
