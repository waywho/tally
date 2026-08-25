class PagesController < ApplicationController
  skip_before_action :ensure_onboarded

  def home
    return redirect_to today_path if rodauth.logged_in?

    # Rodauth sends logout and close-account to "/", and the iOS shell treats a
    # visit to /login as the signal to clear its session and show the native
    # login screen. Serving the marketing page here instead would leave the tab
    # bar up with a dead session behind it.
    return redirect_to rodauth.login_path if native_app?

    render :home, layout: "marketing"
  end
end
