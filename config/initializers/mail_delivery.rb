Rails.application.config.to_prepare do
  MailDelivery.backend =
    case ENV.fetch("MAIL_PROVIDER", "action_mailer")
    when "loops" then MailDelivery::LoopsBackend.new
    else MailDelivery::ActionMailerBackend.new
    end
end
