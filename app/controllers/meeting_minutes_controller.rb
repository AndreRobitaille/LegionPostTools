class MeetingMinutesController < ApplicationController
  before_action :require_authentication

  def show
    @meeting = Organization.first!.meetings.includes(minutes: { current_revision: :attestation }).find(params[:meeting_id])
    @revision = @meeting.minutes&.current_revision
    raise ActiveRecord::RecordNotFound unless @meeting.minutes&.attested? && @revision&.attestation
  end
end
