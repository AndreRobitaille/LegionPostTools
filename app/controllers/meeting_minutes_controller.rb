class MeetingMinutesController < ApplicationController
  before_action :require_authentication

  def show
    @meeting = Organization.first!.meetings.includes(
      minutes: [ :membership_approval, { current_revision: :attestation }, { revisions: :attestation } ]
    ).find(params[:meeting_id])
    @minutes = @meeting.minutes
    @revision = @minutes&.member_revision
    @membership_approval = @minutes&.membership_approval
    raise ActiveRecord::RecordNotFound unless @minutes&.member_visible? && @revision&.attestation
  end
end
