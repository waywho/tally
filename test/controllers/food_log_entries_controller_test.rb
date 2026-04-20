require "test_helper"

class FoodLogEntriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
    @food = create(:food, calories: 250, protein: 10, carbs: 30, fat: 12, fiber: 3)
    @date = "2026-04-19"
  end

  # Create
  test "POST creates entry with correct attributes" do
    login(@account)

    assert_difference "FoodLogEntry.count", 1 do
      post day_food_log_entries_path(day_date: @date), params: {
        food_log_entry: { food_id: @food.id, meal: "breakfast", weight: 150 }
      }
    end

    entry = FoodLogEntry.last
    assert_equal @user.id, entry.user_id
    assert_equal @food.id, entry.food_id
    assert_equal Date.parse(@date), entry.logged_on
    assert_equal "breakfast", entry.meal
    assert_equal 150.0, entry.weight.to_f
    assert_redirected_to day_path(date: @date)
  end

  test "POST with invalid params does not create entry" do
    login(@account)

    assert_no_difference "FoodLogEntry.count" do
      post day_food_log_entries_path(day_date: @date), params: {
        food_log_entry: { food_id: @food.id, meal: "breakfast", weight: 0 }
      }
    end

    assert_response :unprocessable_entity
  end

  test "POST creates entry from USDA transient result" do
    login(@account)

    ENV["USDA_API_KEY"] = "test-key"

    assert_difference ["FoodLogEntry.count", "Food.count"], 1 do
      post day_food_log_entries_path(day_date: @date), params: {
        food_log_entry: {
          meal: "breakfast",
          weight: 100,
          usda_fdc_id: "12345",
          usda_name: "Test USDA Food",
          usda_brand: "Test Brand",
          usda_calories: 200,
          usda_protein: 15,
          usda_carbs: 25,
          usda_fat: 8,
          usda_fiber: 4
        }
      }
    end

    food = Food.last
    assert_equal "usda", food.source
    assert_equal "12345", food.external_id
    assert_equal "Test USDA Food", food.name
    assert_equal 200.0, food.calories.to_f

    entry = FoodLogEntry.last
    assert_equal food.id, entry.food_id
    assert_equal @user.id, entry.user_id
    assert_redirected_to day_path(date: @date)
  ensure
    ENV.delete("USDA_API_KEY")
  end

  test "POST with neither food_id nor usda_fdc_id returns error" do
    login(@account)

    assert_no_difference ["FoodLogEntry.count", "Food.count"] do
      post day_food_log_entries_path(day_date: @date), params: {
        food_log_entry: { meal: "breakfast", weight: 100 }
      }
    end

    assert_response :unprocessable_entity
  end

  test "POST requires authentication" do
    post day_food_log_entries_path(day_date: @date), params: {
      food_log_entry: { food_id: @food.id, meal: "breakfast", weight: 100 }
    }
    assert_response :redirect
  end

  # Edit
  test "GET edit renders form for own entry" do
    login(@account)
    entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.parse(@date), meal: :breakfast, weight: 150)

    get edit_day_food_log_entry_path(day_date: @date, id: entry.id)

    assert_response :success
    assert_select "input[name='food_log_entry[weight]']"
    assert_select "form[action='#{day_food_log_entry_path(day_date: @date, id: entry.id)}']"
  end

  test "GET edit returns 404 for other user's entry" do
    other_user = create(:user)
    entry = create(:food_log_entry, user: other_user, food: @food, logged_on: Date.parse(@date))

    login(@account)
    get edit_day_food_log_entry_path(day_date: @date, id: entry.id)

    assert_response :not_found
  end

  # Update
  test "PATCH updates weight" do
    login(@account)
    entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.parse(@date), weight: 100)

    patch day_food_log_entry_path(day_date: @date, id: entry.id), params: {
      food_log_entry: { weight: 200 }
    }

    assert_redirected_to day_path(date: @date)
    assert_equal 200.0, entry.reload.weight.to_f
  end

  test "PATCH with invalid quantity re-renders form" do
    login(@account)
    entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.parse(@date), weight: 100)

    patch day_food_log_entry_path(day_date: @date, id: entry.id), params: {
      food_log_entry: { weight: 0 }
    }

    assert_response :unprocessable_entity
    assert_equal 100.0, entry.reload.weight.to_f
  end

  test "PATCH returns 404 for other user's entry" do
    other_user = create(:user)
    entry = create(:food_log_entry, user: other_user, food: @food, logged_on: Date.parse(@date))

    login(@account)
    patch day_food_log_entry_path(day_date: @date, id: entry.id), params: {
      food_log_entry: { weight: 200 }
    }

    assert_response :not_found
  end

  # Destroy
  test "DELETE destroys entry and redirects" do
    login(@account)
    entry = create(:food_log_entry, user: @user, food: @food, logged_on: Date.parse(@date))

    assert_difference "FoodLogEntry.count", -1 do
      delete day_food_log_entry_path(day_date: @date, id: entry.id)
    end

    assert_redirected_to day_path(date: @date)
    follow_redirect!
    assert_equal "Entry deleted.", flash[:notice]
  end

  test "DELETE returns 404 for other user's entry" do
    other_user = create(:user)
    entry = create(:food_log_entry, user: other_user, food: @food, logged_on: Date.parse(@date))

    login(@account)

    assert_no_difference "FoodLogEntry.count" do
      delete day_food_log_entry_path(day_date: @date, id: entry.id)
    end

    assert_response :not_found
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
