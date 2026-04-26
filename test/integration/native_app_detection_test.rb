require "test_helper"

class NativeAppDetectionTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
    login(@account)
  end

  test "web request renders the bottom nav" do
    get today_path
    assert_response :success
    assert_select "nav[aria-label='Primary']"
  end

  test "Turbo Native request hides the bottom nav" do
    get today_path, headers: { "HTTP_USER_AGENT" => "Tally/1.0 Turbo Native iOS" }
    assert_response :success
    assert_select "nav[aria-label='Primary']", count: 0
  end

  test "Turbo Native request reduces main padding" do
    get today_path, headers: { "HTTP_USER_AGENT" => "Tally/1.0 Turbo Native iOS" }
    assert_response :success
    assert_select "main.pb-4"
    assert_select "main.pb-24", count: 0
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
