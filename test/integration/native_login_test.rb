require "test_helper"

class NativeLoginTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  test "native login with valid credentials returns JSON" do
    post "/login",
      params: { email: @account.email, password: "password" },
      headers: { "HTTP_USER_AGENT" => "Tally/1.0 Turbo Native iOS" }

    assert_equal "application/json", response.media_type
    json = JSON.parse(response.body)
    assert json["success"]
  end

  test "native login with invalid credentials returns HTML" do
    post "/login",
      params: { email: @account.email, password: "wrong" },
      headers: { "HTTP_USER_AGENT" => "Tally/1.0 Turbo Native iOS" }

    assert_equal "text/html", response.media_type
  end

  test "web login with valid credentials does not return JSON" do
    post "/login",
      params: { email: @account.email, password: "password" }

    # Web login redirects (302), not JSON
    assert_response :redirect
  end
end
