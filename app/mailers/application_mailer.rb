class ApplicationMailer < ActionMailer::Base
  default from: Rails.application.credentials.dig(:gmail, :email)
  layout "mailer"
end
