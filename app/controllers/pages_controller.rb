class PagesController < ApplicationController
  def home
    if rodauth.logged_in?
      render inline: "", layout: "application"
    else
      redirect_to rodauth.login_path
    end
  end
end
