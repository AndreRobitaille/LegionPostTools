module MailDelivery
  class ActionMailerBackend
    def deliver_magic_link(user:, login_url:)
      MagicLinksMailer.login(user, login_url).deliver_later
    end
  end
end
