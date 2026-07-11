class MagicLinksMailer < ApplicationMailer
  def login(user, token)
    @user = user
    @login_url = magic_link_session_url(token: token)

    mail to: user.email_address, subject: "Sign in to LegionPostTools"
  end
end
