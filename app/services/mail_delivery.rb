# Delivery seam so mailer callers do not hard-code a provider. The backend is
# selected in config/initializers/mail_delivery.rb from MAIL_PROVIDER.
module MailDelivery
  mattr_accessor :backend

  def self.deliver_magic_link(user:, login_url:)
    backend.deliver_magic_link(user: user, login_url: login_url)
  end
end
