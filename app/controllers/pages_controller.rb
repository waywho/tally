class PagesController < ApplicationController
  skip_before_action :ensure_onboarded

  def home
    return redirect_to today_path if rodauth.logged_in?

    # Signed-out visitors get the marketing page; the native app never lands
    # here because it opens straight into /today behind its own login screen.
    render :home, layout: "marketing"
  end
end
