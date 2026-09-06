class DashboardController < ApplicationController
  include CalendarTimeZone

  before_action :require_authentication

  def show
    @organization = Organization.first
    meetings = @organization.meetings.includes(
      :meeting_body,
      :meeting_type,
      :dated_agenda,
      minutes: { current_revision: :attestation }
    )
    @next_meeting = meetings.upcoming.detect { |meeting| CalendarCategories.for(meeting) == "member_meeting" }
    @recent_meeting = meetings.past.detect { |meeting| CalendarCategories.for(meeting) == "member_meeting" }
    @upcoming_activities = upcoming_activities
    @show_passkey_invite =
      current_user.passkey_credentials.empty? && !session[:passkey_invite_dismissed]
    @show_roster_email_review = current_user.needs_roster_email_review? && !roster_email_review_suppressed?
  end

  private

  def upcoming_activities
    today = Time.current.beginning_of_day
    events = @organization.calendar_events.where(cancelled: false)
      .where("COALESCE(ends_at, starts_at) >= ?", today)
    meetings = @organization.meetings.upcoming.includes(:meeting_body, :meeting_type)

    (events.to_a + meetings.to_a)
      .reject { |entry| %w[honor_guard officer_meeting member_meeting].include?(CalendarCategories.for(entry)) }
      .sort_by { |entry| [ entry.starts_at, entry.title.downcase, entry.class.name, entry.id ] }
      .first(3)
  end

  def roster_email_review_suppressed?
    session[:roster_email_review_suppressed_for] == current_user.person.roster_email_address
  end
end
