class SessionsController < ApplicationController
  skip_before_action :redirect_to_setup_if_needed, only: %i[new create magic_link]

  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)

    if user&.disabled_at.blank?
      magic_link = MagicLink.create_for!(user)
      MagicLinksMailer.login(user, magic_link.token).deliver_later
    end

    redirect_to new_session_path, notice: "Check your email for a login link."
  end

  def magic_link
    if request.get? || request.head?
      return render :magic_link
    end

    return head :method_not_allowed unless request.post?

    user = MagicLink.consume!(params[:token])

    if user
      start_new_session_for(user)
      redirect_to root_path, notice: "You are signed in."
    else
      redirect_to new_session_path, alert: "That login link is invalid or expired."
    end
  end

  def destroy
    terminate_current_session
    redirect_to new_session_path, notice: "You are signed out."
  end
end
