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

  test "GET / renders the landing page with its screenshots for a visitor" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", "/create-account"
    assert_select "img[src*=?]", "screenshot-today"
  end

  test "GET /support renders for an anonymous visitor" do
    get support_path
    assert_response :success
    assert_select "h1", text: "Support"
  end

  test "GET /manifest serves valid JSON with icons the app actually has" do
    get pwa_manifest_path
    assert_response :success

    manifest = JSON.parse(response.body)
    assert_equal "Tally", manifest["name"]
    manifest["icons"].each do |icon|
      assert File.exist?(Rails.public_path.join(icon["src"].delete_prefix("/"))),
        "manifest references missing icon #{icon["src"]}"
    end
  end
end
