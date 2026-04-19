require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [375, 812]

  def login_as(account)
    visit "/login"
    fill_in "email", with: account.email
    fill_in "password", with: "password"
    click_button "Login"
  end
end
