require "test_helper"

class MealPickersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  test "redirects when not authenticated" do
    get meal_picker_path(meal: "lunch", date: "2026-04-26")
    assert_response :redirect
  end

  test "renders a turbo-frame with all four meal links" do
    login(@account)
    get meal_picker_path(meal: "lunch", date: "2026-04-26")
    assert_response :success
    assert_select "turbo-frame#modal" do
      FoodLogEntry.meals.each_key do |meal_key|
        assert_select "a[href*='meal=#{meal_key}']", text: /#{meal_key.capitalize}/i
        assert_select "a[href*='date=2026-04-26']"
      end
    end
  end

  test "highlights the currently selected meal" do
    login(@account)
    get meal_picker_path(meal: "lunch", date: "2026-04-26")
    assert_response :success
    assert_select "a.text-primary.bg-primary-tint", text: /Lunch/i
  end

  test "preserves the search query when given" do
    login(@account)
    get meal_picker_path(meal: "lunch", date: "2026-04-26", q: "apple")
    assert_response :success
    assert_select "a[href*='q=apple']"
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
