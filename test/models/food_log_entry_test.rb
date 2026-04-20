require "test_helper"

class FoodLogEntryTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @food = create(:food, calories: 250, protein: 10, carbs: 30, fat: 12, fiber: 3)
  end

  # Factory
  test "factory is valid" do
    entry = build(:food_log_entry)
    assert entry.valid?, entry.errors.full_messages.join(", ")
  end

  # Associations
  test "belongs to user" do
    entry = create(:food_log_entry, user: @user)
    assert_equal @user, entry.user
  end

  test "belongs to food" do
    entry = create(:food_log_entry, food: @food)
    assert_equal @food, entry.food
  end

  test "user has many food log entries" do
    create(:food_log_entry, user: @user)
    create(:food_log_entry, user: @user)
    assert_equal 2, @user.food_log_entries.count
  end

  test "destroying user destroys food log entries" do
    create(:food_log_entry, user: @user)
    assert_difference "FoodLogEntry.count", -1 do
      @user.destroy
    end
  end

  # Validations
  test "invalid without user" do
    entry = build(:food_log_entry, user: nil)
    assert_not entry.valid?
    assert entry.errors[:user].any?
  end

  test "invalid without food" do
    entry = build(:food_log_entry, food: nil)
    assert_not entry.valid?
    assert entry.errors[:food].any?
  end

  test "invalid without logged_on" do
    entry = build(:food_log_entry, logged_on: nil)
    assert_not entry.valid?
    assert_includes entry.errors[:logged_on], "can't be blank"
  end

  test "invalid without meal" do
    entry = build(:food_log_entry, meal: nil)
    assert_not entry.valid?
    assert_includes entry.errors[:meal], "can't be blank"
  end

  test "invalid without quantity_g" do
    entry = build(:food_log_entry, quantity_g: nil)
    assert_not entry.valid?
    assert entry.errors[:quantity_g].any?
  end

  test "invalid with quantity_g of zero" do
    entry = build(:food_log_entry, quantity_g: 0)
    assert_not entry.valid?
    assert entry.errors[:quantity_g].any?
  end

  test "invalid with negative quantity_g" do
    entry = build(:food_log_entry, quantity_g: -10)
    assert_not entry.valid?
    assert entry.errors[:quantity_g].any?
  end

  test "valid with positive quantity_g" do
    entry = build(:food_log_entry, quantity_g: 150)
    assert entry.valid?
  end

  # Meal enum
  test "meal enum values" do
    assert FoodLogEntry.meals.key?("breakfast")
    assert FoodLogEntry.meals.key?("lunch")
    assert FoodLogEntry.meals.key?("dinner")
    assert FoodLogEntry.meals.key?("snacks")
  end

  test "breakfast? returns true for breakfast meal" do
    entry = build(:food_log_entry, meal: :breakfast)
    assert entry.breakfast?
  end

  test "lunch? returns true for lunch meal" do
    entry = build(:food_log_entry, meal: :lunch)
    assert entry.lunch?
  end

  test "dinner? returns true for dinner meal" do
    entry = build(:food_log_entry, meal: :dinner)
    assert entry.dinner?
  end

  test "snacks? returns true for snacks meal" do
    entry = build(:food_log_entry, meal: :snacks)
    assert entry.snacks?
  end

  # Computed methods
  test "calories computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 500.0, entry.calories
  end

  test "protein computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 20.0, entry.protein
  end

  test "carbs computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 60.0, entry.carbs
  end

  test "fat computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 24.0, entry.fat
  end

  test "fiber computed from food per 100g and quantity" do
    entry = build(:food_log_entry, food: @food, quantity_g: 200)
    assert_equal 6.0, entry.fiber
  end

  test "computed values work with decimal quantities" do
    entry = build(:food_log_entry, food: @food, quantity_g: 150)
    assert_equal 375.0, entry.calories
    assert_equal 15.0, entry.protein
    assert_equal 45.0, entry.carbs
    assert_equal 18.0, entry.fat
    assert_equal 4.5, entry.fiber
  end
end
