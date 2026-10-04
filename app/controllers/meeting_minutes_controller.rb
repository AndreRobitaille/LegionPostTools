class MeetingMinutesController < ApplicationController
  before_action :require_authentication
  before_action :set_member_minutes

  def show
    if params[:revision].present? && params[:revision].to_s != @revision.id.to_s
      redirect_to meeting_minutes_path(@meeting), notice: "These minutes have a newer member-visible revision. The earlier citation is no longer current."
    end
  end

  def print
    pdf = MeetingMinutesPdf.render(minutes: @minutes, revision: @revision)
    send_data pdf,
      filename: MeetingMinutesPdf.filename(minutes: @minutes, revision: @revision),
      type: "application/pdf",
      disposition: "inline"
    no_store
  rescue MeetingMinutesPdf::GenerationError => error
    Rails.logger.error("Member minutes PDF generation failed: #{error.message}")
    redirect_to meeting_minutes_path(@meeting), alert: "The minutes PDF could not be created. Try again."
  end

  private

  def set_member_minutes
    @meeting = Organization.first!.meetings.includes(
      minutes: [ :membership_approval, { current_revision: :attestation }, { revisions: :attestation } ]
    ).find(params[:meeting_id])
    @minutes = @meeting.minutes
    @revision = @minutes&.member_revision
    @membership_approval = @minutes&.membership_approval
    raise ActiveRecord::RecordNotFound unless @minutes&.member_visible? && @revision&.attestation
  end
end
