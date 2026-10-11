class MembershipPdfSourcesController < ApplicationController
  include PdfResourcePolicy

  skip_before_action :redirect_to_setup_if_needed
  skip_before_action :resume_session

  def show
    response.cache_control.replace(no_store: true)
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    return head :not_found unless request.local?

    payload = MembershipPdf.verify_source_token!(params.require(:token))
    @organization = Organization.find(payload.fetch("organization_id"))
    user = User.where(disabled_at: nil).find(payload.fetch("user_id"))
    access = MembershipAccess.new(user:, organization: @organization)

    if payload["drive_id"]
      @drive = access.drives.find(payload.fetch("drive_id"))
      @workspace = MembershipWorkspace.new(user:, organization: @organization, membership_year: @drive.membership_year)
      @assignments = access.drive_assignments(@drive, caller_id: payload["caller_id"])
        .where(revoked_at: nil).where("membership_assignments.expires_on >= ?", Organization.current_local_date)
        .where(people: { roster_removed_at: nil })
        .where("LOWER(TRIM(COALESCE(people.roster_member_status, ''))) != ?", "deceased")
        .select { |assignment| @workspace.contact_work_item(assignment.person, purpose: @drive.purpose, assignment:)[:outreach_needed] }
      @packet_id = payload.fetch("packet_id")
      render "membership/drives/print", layout: "print"
    elsif payload["summary_id"] && access.manager?
      @summary_record = @organization.membership_summaries.find(payload.fetch("summary_id"))
      @summary = @summary_record.payload
      render "membership/summaries/print", layout: "print"
    else
      head :not_found
    end
  rescue ActiveRecord::RecordNotFound, ActionController::ParameterMissing,
         ActiveSupport::MessageVerifier::InvalidSignature, ArgumentError, KeyError, TypeError
    head :not_found
  end
end
