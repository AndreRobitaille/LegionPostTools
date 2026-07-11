class SessionsController < ApplicationController
  layout "entry", only: %i[new create magic_link]
  skip_before_action :redirect_to_setup_if_needed, only: %i[new create magic_link]

  rate_limit to: 10,
    within: 5.minutes,
    only: :create,
    name: :magic_link_request,
    by: -> { request.remote_ip },
    with: :redirect_after_auth_throttle

  rate_limit to: 10,
    within: 5.minutes,
    only: :magic_link,
    name: :magic_link_consumption,
    by: -> { request.remote_ip },
    if: -> { request.post? },
    with: :redirect_after_auth_throttle

  def new
    @organization = Organization.first
  end

  def create
    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)

    if user && user.disabled_at.blank?
      magic_link = MagicLink.create_for!(user)
      login_url = magic_link_session_url(token: magic_link.token)
      MailDelivery.deliver_magic_link(user: user, login_url: login_url)
    end

    redirect_to new_session_path, notice: "Check your email for a login link."
  end

  def magic_link
    @organization = Organization.first

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

  private

  def redirect_after_auth_throttle
    redirect_to new_session_path, alert: "Please wait a few minutes and try again."
  end
end
