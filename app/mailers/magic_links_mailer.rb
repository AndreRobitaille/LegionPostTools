class MagicLinksMailer < ApplicationMailer
  def login(user, login_url)
    @user = user
    @login_url = login_url

    mail to: user.email_address, subject: "Sign in to LegionPostTools"
  end
end
