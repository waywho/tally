class RodauthController < ApplicationController
  AUTH_ROUTES = %i[
    login create_account
    verify_account verify_account_resend
    reset_password reset_password_request
  ].freeze

  layout -> { AUTH_ROUTES.include?(rodauth.current_route) ? "authentication" : "application" }
end
