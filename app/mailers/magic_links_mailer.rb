class MagicLinksMailer < ApplicationMailer
  def login(user, login_url, login_code)
    @user = user
    @login_url = login_url
    @login_code = login_code

    mail to: user.email_address, subject: "Sign in to LegionPostTools"
  end

  def agent_access_confirmation(user, confirmation_code)
    @user = user
    @confirmation_code = confirmation_code

    mail to: user.email_address, subject: "Confirm agent access in LegionPostTools"
  end
end
