module Membership
  class DuesRecordsController < BaseController
    before_action :require_membership_manager

    def create
      attributes = params.expect(membership_dues_record: [ :person_id, :kind, :received_on, :amount, :reference, :notes, :submission_key ]).to_h.symbolize_keys
      @dues_record = @workspace.record_dues!(attributes)
      redirect_to record_destination(@dues_record), notice: "Membership entry recorded.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @dues_record = error.record
      if @dues_record.person_id
        params[:person_id] = @dues_record.person_id
        load_member_context
        render "membership/people/show", status: :unprocessable_entity
      else
        load_post_checks
        render "membership/post_checks/index", status: :unprocessable_entity
      end
    end

    def reverse
      original = @organization.membership_dues_records.find(params[:id])
      attributes = params.expect(correction: [ :notes, :submission_key ])
      @workspace.reverse_dues!(original.id, notes: attributes[:notes], submission_key: attributes[:submission_key])
      redirect_to record_destination(original), notice: "Correction recorded. The original entry is preserved.", status: :see_other
    rescue ActiveRecord::RecordInvalid => error
      @message = error.record.errors.full_messages.to_sentence
      render "membership/error", status: :unprocessable_entity
    end

    private

    def record_destination(record)
      record.person_id ? membership_person_path(record.person_id, membership_year: record.membership_year) : membership_post_checks_path(membership_year: record.membership_year)
    end
  end
end
