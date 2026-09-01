class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    @organization = Organization.first
    meetings = @organization.meetings.includes(
      :meeting_body,
      :meeting_type,
      :dated_agenda,
      minutes: { current_revision: :attestation }
    )
    @next_meeting = meetings.upcoming.first
    @recent_meeting = meetings.past.first
    @show_passkey_invite =
      current_user.passkey_credentials.empty? && !session[:passkey_invite_dismissed]
    @show_roster_email_review = current_user.needs_roster_email_review? && !roster_email_review_suppressed?
  end

  private

  def roster_email_review_suppressed?
    session[:roster_email_review_suppressed_for] == current_user.person.roster_email_address
  end
end
