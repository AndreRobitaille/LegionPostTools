class MeetingsController < ApplicationController
  before_action :require_authentication
  before_action :set_organization

  def index
    meetings = @organization.meetings.includes(
      :meeting_body,
      :meeting_type,
      :dated_agenda,
      minutes: { current_revision: :attestation }
    )
    @upcoming_meetings = meetings.upcoming.to_a
    @next_meeting = @upcoming_meetings.shift
    @past_meetings_by_year = meetings.past.group_by do |meeting|
      meeting.starts_at.in_time_zone.year
    end
  end

  def show
    @meeting = @organization.meetings.includes(:meeting_body, :meeting_type, :dated_agenda, minutes: { current_revision: :attestation }).find(params[:id])
    @published_agenda = @meeting.dated_agenda if @meeting.dated_agenda&.published?
    @attested_minutes = @meeting.minutes if @meeting.minutes&.attested?
  end

  private

  def set_organization
    @organization = Organization.first!
  end
end
