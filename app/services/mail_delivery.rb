# Delivery seam so mailer callers do not hard-code a provider. The backend is
# selected in config/initializers/mail_delivery.rb from MAIL_PROVIDER.
module MailDelivery
  mattr_accessor :backend

  def self.deliver_magic_link(user:, login_url:, login_code:)
    backend.deliver_magic_link(user: user, login_url: login_url, login_code: login_code)
  end

  def self.deliver_agent_access_confirmation(user:, confirmation_code:)
    backend.deliver_agent_access_confirmation(user: user, confirmation_code: confirmation_code)
  end
end
