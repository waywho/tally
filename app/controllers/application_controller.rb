class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :ensure_live_account
  before_action :ensure_onboarded

  private

  # A session can outlive its account — closing an account leaves the cookie in
  # place, and the iOS shell keeps one in the Keychain. Every current_user call
  # would then return nil and blow up downstream.
  def ensure_live_account
    return unless rodauth.logged_in?
    return if current_account

    rodauth.logout
    redirect_to rodauth.login_path
  end

  def require_authentication
    rodauth.require_authentication
  end

  def ensure_onboarded
    return unless rodauth.logged_in?
    return if current_user&.onboarded_at.present?

    redirect_to onboarding_step_path(:step1)
  end

  def current_user
    @current_user ||= current_account&.user
  end
  helper_method :current_user

  def current_account
    @current_account ||= Account.find_by(id: rodauth.session_value)
  end
  helper_method :current_account

  def native_app?
    request.user_agent.to_s.include?("Turbo Native")
  end
  helper_method :native_app?
end
