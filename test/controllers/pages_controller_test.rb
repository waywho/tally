require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  # App Store Connect fetches these URLs anonymously, so they must render
  # without a session.
  test "GET /privacy renders for an anonymous visitor" do
    get privacy_path
    assert_response :success
    assert_select "h1", text: "Privacy Policy"
  end

  test "GET /terms renders for an anonymous visitor" do
    get terms_path
    assert_response :success
    assert_select "h1", text: "Terms of Use"
  end
end
