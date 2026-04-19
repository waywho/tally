require "test_helper"

class FoodsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  test "index redirects when not authenticated" do
    get foods_path(q: "chicken")
    assert_response :redirect
  end

  test "index renders search page when authenticated" do
    login(@account)
    get foods_path
    assert_response :success
    assert_select "input[name='q']"
    assert_select "turbo-frame#food_search_results"
  end

  test "index returns results for valid query" do
    5.times { |i| create(:food, name: "Chicken item #{i}", source: :off, external_id: "ctrl-#{i}") }

    login(@account)
    get foods_path(q: "chicken")

    assert_response :success
    assert_select "[data-food-result]", count: 5
  end

  test "index returns empty state for short query" do
    login(@account)
    get foods_path(q: "ch")

    assert_response :success
    assert_select "[data-food-result]", count: 0
  end

  test "index returns empty state for blank query" do
    login(@account)
    get foods_path(q: "")

    assert_response :success
    assert_select "[data-food-result]", count: 0
  end

  test "index responds to turbo frame request" do
    5.times { |i| create(:food, name: "Chicken item #{i}", source: :off, external_id: "frame-#{i}") }

    login(@account)
    get foods_path(q: "chicken"), headers: { "Turbo-Frame" => "food_search_results" }

    assert_response :success
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
