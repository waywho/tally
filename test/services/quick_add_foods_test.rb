require "test_helper"

class QuickAddFoodsTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @chicken = create(:food, name: "Chicken breast", calories: 120)
    @rice = create(:food, name: "Brown rice", calories: 130)
    @oats = create(:food, name: "Oatmeal", calories: 70)
    @pasta = create(:food, name: "Pasta", calories: 160)
  end

  test "returns foods ordered by frequency then recency" do
    # Chicken logged 3 times, rice logged 1 time
    3.times { |i| create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: i.days.ago.to_date) }
    create(:food_log_entry, user: @user, food: @rice, meal: :lunch, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch")

    assert_equal @chicken, results.first
    assert_equal @rice, results.second
  end

  test "scopes to current meal first then fills with global" do
    # Chicken logged for lunch, oats logged for breakfast
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)
    create(:food_log_entry, user: @user, food: @oats, meal: :breakfast, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch", limit: 10)

    assert_includes results, @chicken
    assert_includes results, @oats
    # Chicken should be first (meal-scoped)
    assert_equal @chicken, results.first
  end

  test "deduplicates between meal-scoped and global results" do
    # Chicken logged for both lunch and breakfast
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)
    create(:food_log_entry, user: @user, food: @chicken, meal: :breakfast, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch")

    chicken_count = results.count { |f| f.id == @chicken.id }
    assert_equal 1, chicken_count
  end

  test "caps at limit" do
    12.times do |i|
      food = create(:food, name: "Food #{i}", calories: 100)
      create(:food_log_entry, user: @user, food: food, meal: :lunch, logged_on: Date.current)
    end

    results = QuickAddFoods.call(user: @user, meal: "lunch", limit: 10)

    assert_equal 10, results.size
  end

  test "returns empty array for user with no history" do
    results = QuickAddFoods.call(user: @user, meal: "lunch")

    assert_empty results
  end

  test "excludes foods the user has never logged" do
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch")

    assert_includes results, @chicken
    assert_not_includes results, @rice
    assert_not_includes results, @oats
  end

  test "does not include other users log history" do
    other_user = create(:user)
    create(:food_log_entry, user: other_user, food: @pasta, meal: :lunch, logged_on: Date.current)
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch")

    assert_includes results, @chicken
    assert_not_includes results, @pasta
  end

  test "meal-scoped results come before global results" do
    create(:food_log_entry, user: @user, food: @oats, meal: :breakfast, logged_on: Date.current)
    create(:food_log_entry, user: @user, food: @chicken, meal: :lunch, logged_on: Date.current)

    results = QuickAddFoods.call(user: @user, meal: "lunch", limit: 10)

    lunch_index = results.index(@chicken)
    breakfast_index = results.index(@oats)
    assert lunch_index < breakfast_index, "Meal-scoped food should come before global"
  end
end
