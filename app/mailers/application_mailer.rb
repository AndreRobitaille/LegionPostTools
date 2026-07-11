class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", Rails.env.production? ? nil : "from@example.com")
  layout "mailer"
end
