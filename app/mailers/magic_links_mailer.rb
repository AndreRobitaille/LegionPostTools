class MagicLinksMailer < ApplicationMailer
  def login(user, login_url, login_code)
    @user = user
    @login_url = login_url
    @login_code = login_code

    mail to: user.email_address, subject: "Your LegionPostTools code and link"
  end
end
