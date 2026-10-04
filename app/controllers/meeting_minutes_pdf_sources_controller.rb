class MeetingMinutesPdfSourcesController < ApplicationController
  include PdfResourcePolicy

  skip_before_action :redirect_to_setup_if_needed
  skip_before_action :resume_session

  def show
    return head :not_found unless request.local?

    payload = MeetingMinutesPdf.verify_source_token!(params.require(:token))
    @organization = Organization.find(payload.fetch("organization_id"))
    @minutes = @organization.meeting_minutes.includes(
      :meeting_body,
      :meeting_type,
      :attendance_entries,
      membership_approval: :approving_meeting,
      current_revision: :attestation,
      sections: { items: %i[rich_text_agenda_body rich_text_body outcomes] }
    ).find(payload.fetch("meeting_minutes_id"))

    response.headers["Cache-Control"] = "private, no-store"
    response.headers["X-Robots-Tag"] = "noindex, nofollow"
    if payload.key?("member_revision_id")
      @revision = @minutes.member_revision
      raise ActiveRecord::RecordNotFound unless @revision&.attestation && @revision.id == payload.fetch("member_revision_id")

      @membership_approval = @minutes.membership_approval
      render "meeting_minutes/member_print", layout: "print"
    else
      render "meeting_minutes/print", layout: "print"
    end
  rescue ActionController::ParameterMissing,
         ActiveRecord::RecordNotFound,
         ActiveSupport::MessageVerifier::InvalidSignature,
         KeyError
    head :not_found
  end
end
