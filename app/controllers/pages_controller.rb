class PagesController < ApplicationController
  skip_before_action :ensure_onboarded

  def home
    if rodauth.logged_in?
      redirect_to edit_settings_path
    else
      redirect_to rodauth.login_path
    end
  end
end
