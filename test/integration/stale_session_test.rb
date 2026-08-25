require "test_helper"

# Closing an account leaves its cookie in the browser, and the iOS shell keeps
# one in the Keychain, so requests keep arriving for accounts that are gone.
class StaleSessionTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    create(:user, account: @account)
    post "/login", params: { email: @account.email, password: "password" }
    @account.destroy!
  end

  test "a session for a deleted account is sent to login, not a 500" do
    get today_path
    assert_redirected_to "/login"
  end

  test "onboarding does not render a form with no user" do
    get onboarding_step_path(:step1)
    assert_redirected_to "/login"
  end

  test "settings does not render for a deleted account" do
    get edit_settings_path
    assert_redirected_to "/login"
  end
end
