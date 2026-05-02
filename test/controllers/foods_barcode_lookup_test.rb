require "test_helper"

class FoodsBarcodeLoopkupTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
    login(@account)
  end

  test "renders index with barcode food when found locally" do
    food = create(:food, barcode: "1234567890123", name: "Test Local Food")

    get barcode_lookup_foods_path(code: "1234567890123", meal: "lunch", date: "2026-05-01")

    assert_response :success
    assert_select "#barcode-auto-open", false # no hidden button
    assert response.body.include?("Test Local Food") # food name appears in the auto-open script
  end

  test "redirects with not_found when barcode not in DB and OFF unavailable" do
    stub_request(:get, "https://world.openfoodfacts.org/api/v2/product/0000000000000.json")
      .to_return(status: 404, body: "", headers: {})

    get barcode_lookup_foods_path(code: "0000000000000", meal: "lunch", date: "2026-05-01")

    assert_redirected_to foods_path(barcode_not_found: 1, barcode: "0000000000000", meal: "lunch", date: "2026-05-01")
  end

  test "requires authentication" do
    stub_request(:get, "https://world.openfoodfacts.org/api/v2/product/1234567890123.json")
      .to_return(status: 404, body: "", headers: {})

    delete "/logout"
    get barcode_lookup_foods_path(code: "1234567890123")
    assert_response :redirect
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
