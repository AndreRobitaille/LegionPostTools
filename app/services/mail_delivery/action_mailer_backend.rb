module MailDelivery
  class ActionMailerBackend
    def deliver_magic_link(user:, login_url:, login_code:)
      MagicLinksMailer.login(user, login_url, login_code).deliver_later
    end

    def deliver_agent_access_confirmation(user:, confirmation_code:)
      MagicLinksMailer.agent_access_confirmation(user, confirmation_code).deliver_later
    end
  end
end
