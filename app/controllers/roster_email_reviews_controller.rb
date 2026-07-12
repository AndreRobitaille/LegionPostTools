class RosterEmailReviewsController < ApplicationController
  before_action :require_authentication

  def update
    case params[:decision]
    when "update_login"
      current_user.update_login_email_to_roster_email!
      redirect_to root_path, notice: "Your login email now matches the roster email."
    when "keep_current"
      current_user.keep_current_login_email!
      redirect_to root_path, notice: "Your current login email will be kept."
    when "remind_later"
      current_user.remind_later_about_roster_email!
      session[:roster_email_review_suppressed_for] = current_user.person.roster_email_address
      redirect_to root_path, notice: "We will remind you next time you sign in."
    else
      redirect_to root_path, alert: "Choose how to handle the roster email difference."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to root_path, alert: e.record.errors.full_messages.to_sentence
  end
end
