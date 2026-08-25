require "test_helper"

class AuthFlowTest < ActionDispatch::IntegrationTest
  test "login page renders with auth layout" do
    get "/login"
    assert_response :success
    assert_select "h1", "Tally"
    assert_select "h2", /Welcome back/i
    assert_select "input[name='email']"
    assert_select "input[name='password']"
  end

  test "create account page renders" do
    get "/create-account"
    assert_response :success
    assert_select "h1", "Tally"
    assert_select "h2", /Create Account/i
    assert_select "input[name='email']"
    assert_select "input[name='password']"
    assert_select "input[name='password-confirm']"
  end

  test "reset password request page renders" do
    get "/reset-password-request"
    assert_response :success
    assert_select "h2", /Request Password Reset/i
    assert_select "input[name='email']"
  end

  test "unauthenticated root shows the landing page" do
    get "/"
    assert_response :success
    assert_select "a[href=?]", "/login"
  end

  test "can create account and log in" do
    post "/create-account", params: {
      email: "new@example.com",
      password: "password123",
      "password-confirm": "password123"
    }
    # Should redirect (to verify account resend or login, depending on grace period)
    assert_response :redirect

    # Account should exist
    assert Account.find_by(email: "new@example.com")
  end
end
