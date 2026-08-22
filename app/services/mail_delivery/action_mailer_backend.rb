module MailDelivery
  class ActionMailerBackend
    def deliver_magic_link(user:, login_url:, login_code:)
      MagicLinksMailer.login(user, login_url, login_code).deliver_later
    end
  end
end
