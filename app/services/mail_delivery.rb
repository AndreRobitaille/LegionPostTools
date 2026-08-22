# Delivery seam so mailer callers do not hard-code a provider. The backend is
# selected in config/initializers/mail_delivery.rb from MAIL_PROVIDER.
module MailDelivery
  mattr_accessor :backend

  class DeliveryError < StandardError
    attr_reader :status

    def initialize(message, status: nil)
      @status = status
      super(message)
    end
  end

  def self.deliver_magic_link(user:, login_url:, login_code:)
    backend.deliver_magic_link(user: user, login_url: login_url, login_code: login_code)
  end
end
