require "test_helper"

class DaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account, daily_calorie_target: 2000, protein_target: 50, carbs_target: 250, fat_target: 65, fiber_target: 30)
    @food = create(:food, calories: 250, protein: 10, carbs: 30, fat: 12, fiber: 3)
  end

  test "GET /today redirects to login when not authenticated" do
    get today_path
    assert_response :redirect
  end

  test "GET /today renders today's date for authenticated user" do
    login(@account)
    get today_path
    assert_response :success
    assert_select "[data-date='#{Date.current.iso8601}']"
  end

  test "GET /days/:date renders specific date" do
    login(@account)
    get day_path(date: "2026-04-19")
    assert_response :success
    assert_select "[data-date='2026-04-19']"
  end

  test "shows entries grouped by meal" do
    breakfast_entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.current, meal: :breakfast, quantity_g: 200)
    lunch_entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.current, meal: :lunch, quantity_g: 150)

    login(@account)
    get today_path

    assert_response :success
    assert_select "[data-meal='breakfast']" do
      assert_select "[data-entry-id='#{breakfast_entry.id}']"
    end
    assert_select "[data-meal='lunch']" do
      assert_select "[data-entry-id='#{lunch_entry.id}']"
    end
  end

  test "shows calorie summary card with consumed and target" do
    create(:food_log_entry, user: @user, food: @food, logged_on: Date.current, meal: :breakfast, quantity_g: 200)

    login(@account)
    get today_path

    assert_response :success
    assert_select "[data-calorie-summary]"
  end

  test "shows empty state for meals with no entries" do
    login(@account)
    get today_path

    assert_response :success
    assert_select "[data-meal='breakfast']"
    assert_select "[data-empty-meal]", minimum: 1
  end

  test "does not show other user's entries" do
    other_user = create(:user)
    create(:food_log_entry, user: other_user, food: @food, logged_on: Date.current, meal: :breakfast, quantity_g: 100)

    login(@account)
    get today_path

    assert_response :success
    assert_select "[data-entry-id]", count: 0
  end

  test "shows prev/next date navigation links" do
    login(@account)
    get day_path(date: "2026-04-20")

    assert_response :success
    assert_select "a[href='#{day_path(date: '2026-04-19')}']"
    assert_select "a[href='#{day_path(date: '2026-04-21')}']"
  end

  test "shows date picker input" do
    login(@account)
    get day_path(date: "2026-04-20")

    assert_response :success
    assert_select "input[type='date'][value='2026-04-20']"
  end

  test "shows Today label when viewing current date" do
    login(@account)
    get today_path

    assert_response :success
    assert_select "h1", "Today"
  end

  test "home page redirects to today for logged in user" do
    login(@account)
    get root_path
    assert_redirected_to today_path
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
