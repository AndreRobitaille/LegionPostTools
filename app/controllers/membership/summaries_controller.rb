module Membership
  class SummariesController < BaseController
    before_action :require_membership_manager

    def create
      @summary_record = @workspace.save_summary!(submission_key: params.require(:submission_key))
      redirect_to membership_summary_path(@summary_record), notice: "Adjutant summary saved.", status: :see_other
    end

    def show
      @summary_record = @organization.membership_summaries.find(params[:id])
      @summary = @summary_record.payload
    end

    def print
      @summary_record = @organization.membership_summaries.find(params[:id])
      pdf = MembershipPdf.render(organization: @organization, user: current_user, summary: @summary_record)
      send_data pdf, filename: "adjutant-membership-#{@summary_record.membership_year}-#{@summary_record.id}.pdf", type: "application/pdf", disposition: "inline"
    rescue MembershipPdf::GenerationError
      redirect_to membership_summary_path(@summary_record), alert: "The summary PDF could not be created. Try again."
    end
  end
end
