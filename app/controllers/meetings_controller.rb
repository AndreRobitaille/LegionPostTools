class MeetingsController < ApplicationController
  before_action :require_authentication
  before_action :set_organization

  def index
    @upcoming_meetings = @organization.meetings.upcoming.includes(:meeting_body, :dated_agenda).to_a
    @next_meeting = @upcoming_meetings.shift
    @past_meetings_by_year = @organization.meetings.past.includes(:meeting_body, :dated_agenda).group_by do |meeting|
      meeting.starts_at.in_time_zone.year
    end
  end

  def show
    @meeting = @organization.meetings.includes(:meeting_body, :meeting_type, :dated_agenda).find(params[:id])
    @published_agenda = @meeting.dated_agenda if @meeting.dated_agenda&.published?
  end

  private

  def set_organization
    @organization = Organization.first!
  end
end
