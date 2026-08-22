class SessionsController < ApplicationController
  PENDING_SIGN_IN_COOKIE = :pending_sign_in

  layout "entry", only: %i[new create code magic_link]
  skip_before_action :redirect_to_setup_if_needed, only: %i[new create code magic_link]

  # Request throttle is keyed on account + IP so officers sharing one network
  # (e.g. a post hall) don't throttle each other; it still caps one account
  # being hammered from a single IP.
  rate_limit to: 10,
    within: 5.minutes,
    only: :create,
    name: :magic_link_request,
    by: -> { "#{params[:email_address].to_s.strip.downcase}:#{request.remote_ip}" },
    with: :redirect_after_auth_throttle

  # Consumption carries only a token (no account), so it stays per-IP. The limit
  # is generous enough for a whole post clicking their links from one network,
  # while still capping token guessing from a single IP (tokens are 256-bit).
  rate_limit to: 30,
    within: 5.minutes,
    only: :magic_link,
    name: :magic_link_consumption,
    by: -> { request.remote_ip },
    if: -> { request.post? },
    with: :redirect_after_auth_throttle

  rate_limit to: 10,
    within: 5.minutes,
    only: :code,
    name: :email_code_consumption,
    by: -> { "#{request.remote_ip}:#{pending_selector_fingerprint}" },
    if: -> { request.post? },
    with: :redirect_after_auth_throttle

  def new
    @organization = Organization.first
  end

  def create
    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
    browser_challenge = SecureRandom.urlsafe_base64(32)

    if user && user.disabled_at.blank?
      begin
        magic_link = MagicLink.create_for!(user)
        browser_challenge = magic_link.browser_challenge
        login_url = magic_link_session_url(token: magic_link.token)
        MailDelivery.deliver_magic_link(
          user: user,
          login_url: login_url,
          login_code: MagicLink.format_code(magic_link.login_code)
        )
      rescue MailDelivery::DeliveryError => error
        Rails.logger.error("Sign-in email delivery failed status=#{error.status || "unavailable"} message=#{error.message.inspect}")
      end
    end

    set_pending_cookie(PENDING_SIGN_IN_COOKIE, browser_challenge)
    redirect_to code_session_path, notice: "Check your email for a sign-in link and 8-digit code."
  end

  def code
    @organization = Organization.first
    return if request.get? || request.head?
    return head :method_not_allowed unless request.post?

    user = MagicLink.consume_code!(
      browser_challenge: cookies.encrypted[PENDING_SIGN_IN_COOKIE],
      code: params[:code]
    )

    if user
      cookies.delete(PENDING_SIGN_IN_COOKIE)
      start_new_session_for(user)
      redirect_to root_path, notice: "You are signed in."
    else
      redirect_to code_session_path, alert: "That code is invalid or expired. Request a new email and try again."
    end
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
    destination = action_name == "code" ? code_session_path : new_session_path
    redirect_to destination, alert: "Please wait a few minutes and try again."
  end

  def set_pending_cookie(name, value)
    cookies.encrypted[name] = {
      value: value,
      expires: MagicLink::TOKEN_TTL.from_now,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def pending_selector_fingerprint
    selector = cookies.encrypted[PENDING_SIGN_IN_COOKIE].presence || "missing"
    MagicLink.digest(selector).first(16)
  end
end
