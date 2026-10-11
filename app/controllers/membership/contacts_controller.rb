module Membership
  class ContactsController < BaseController
    def create
      attributes = params.expect(membership_contact: [ :membership_assignment_id, :purpose, :occurred_on, :channel, :outcome, :notes, :follow_up_on, :paper_reference, :submission_key ]).to_h.symbolize_keys
      entry = @workspace.record_contact!(attributes.merge(person_id: params[:person_id]))
      notice = entry.channel == "administrative_review" ? "Review recorded." : "Contact recorded."
      redirect_to membership_person_path(params[:person_id], membership_year: @membership_year), notice:, status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @contact = error.record
      load_member_context
      render "membership/people/show", status: :unprocessable_entity
    end
  end
end
