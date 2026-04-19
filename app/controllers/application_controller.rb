class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :ensure_onboarded

  private

  def require_authentication
    rodauth.require_authentication
  end

  def ensure_onboarded
    return unless rodauth.logged_in?
    return if current_user&.onboarded_at.present?

    redirect_to step1_onboarding_path
  end

  def current_user
    @current_user ||= current_account&.user
  end
  helper_method :current_user

  def current_account
    @current_account ||= Account.find_by(id: rodauth.session_value)
  end
  helper_method :current_account
end
