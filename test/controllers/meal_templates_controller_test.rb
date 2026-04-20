require "test_helper"

class MealTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  # Authentication
  test "index redirects when not authenticated" do
    get meal_templates_path
    assert_response :redirect
  end

  # Index
  test "index lists current user templates" do
    template = create(:meal_template, user: @user, name: "My Breakfast")
    create(:meal_template_item, meal_template: template)

    other_user = create(:user)
    create(:meal_template, user: other_user, name: "Other Template")

    login(@account)
    get meal_templates_path

    assert_response :success
    assert_select "[data-template]", count: 1
    assert_select "[data-template]", text: /My Breakfast/
  end

  test "index shows empty state when no templates" do
    login(@account)
    get meal_templates_path

    assert_response :success
    assert_select "p", text: /haven't saved any meal templates/
  end

  # New
  test "new pre-fills from meal entries" do
    food = create(:food, name: "Oatmeal", calories: 150)
    create(:food_log_entry, user: @user, food: food, meal: :breakfast, logged_on: Date.parse("2026-04-21"), weight: 200)

    login(@account)
    get new_meal_template_path(date: "2026-04-21", meal: "breakfast")

    assert_response :success
    assert_select "input[name='meal_template[name]']"
    assert_select "[data-preview-item]", count: 1
    assert_select "[data-preview-item]", text: /Oatmeal/
  end

  test "new shows empty state when no entries for meal" do
    login(@account)
    get new_meal_template_path(date: "2026-04-21", meal: "breakfast")

    assert_response :success
    assert_select "[data-empty-preview]"
  end

  test "new redirects when not authenticated" do
    get new_meal_template_path(date: "2026-04-21", meal: "breakfast")
    assert_response :redirect
  end

  # Create
  test "create saves template with items from meal entries" do
    food_a = create(:food, name: "Eggs")
    food_b = create(:food, name: "Toast")
    create(:food_log_entry, user: @user, food: food_a, meal: :breakfast, logged_on: Date.parse("2026-04-21"), weight: 120)
    create(:food_log_entry, user: @user, food: food_b, meal: :breakfast, logged_on: Date.parse("2026-04-21"), weight: 60)

    login(@account)

    assert_difference "MealTemplate.count", 1 do
      assert_difference "MealTemplateItem.count", 2 do
        post meal_templates_path, params: {
          meal_template: { name: "Quick Breakfast" },
          date: "2026-04-21",
          meal: "breakfast"
        }
      end
    end

    template = MealTemplate.last
    assert_equal "Quick Breakfast", template.name
    assert_equal @user.id, template.user_id
    assert_equal 2, template.meal_template_items.count

    food_ids = template.meal_template_items.pluck(:food_id)
    assert_includes food_ids, food_a.id
    assert_includes food_ids, food_b.id

    assert_redirected_to meal_templates_path
    assert_equal "Template saved.", flash[:notice]
  end

  test "create with blank name re-renders form" do
    food = create(:food)
    create(:food_log_entry, user: @user, food: food, meal: :breakfast, logged_on: Date.parse("2026-04-21"), weight: 100)

    login(@account)

    assert_no_difference "MealTemplate.count" do
      post meal_templates_path, params: {
        meal_template: { name: "" },
        date: "2026-04-21",
        meal: "breakfast"
      }
    end

    assert_response :unprocessable_entity
  end

  # Destroy
  test "destroy removes template" do
    template = create(:meal_template, user: @user)
    create(:meal_template_item, meal_template: template)

    login(@account)

    assert_difference "MealTemplate.count", -1 do
      assert_difference "MealTemplateItem.count", -1 do
        delete meal_template_path(template)
      end
    end

    assert_redirected_to meal_templates_path
    assert_equal "Template deleted.", flash[:notice]
  end

  test "destroy returns 404 for non-owner" do
    other_user = create(:user)
    template = create(:meal_template, user: other_user)

    login(@account)
    delete meal_template_path(template)
    assert_response :not_found
  end

  # Log
  test "log creates food_log_entries for all template items" do
    food_a = create(:food, name: "Eggs")
    food_b = create(:food, name: "Toast")
    template = create(:meal_template, user: @user, name: "Quick Breakfast")
    create(:meal_template_item, meal_template: template, food: food_a, weight: 120)
    create(:meal_template_item, meal_template: template, food: food_b, weight: 60)

    login(@account)

    assert_difference "FoodLogEntry.count", 2 do
      post log_meal_template_path(template), params: {
        date: "2026-04-21",
        meal: "lunch"
      }
    end

    entries = FoodLogEntry.last(2)
    entries.each do |entry|
      assert_equal @user.id, entry.user_id
      assert_equal "lunch", entry.meal
      assert_equal Date.parse("2026-04-21"), entry.logged_on
    end

    food_ids = entries.map(&:food_id)
    assert_includes food_ids, food_a.id
    assert_includes food_ids, food_b.id

    weights = entries.sort_by(&:food_id).map(&:weight)
    expected_weights = [food_a, food_b].sort_by(&:id).map { |f| f == food_a ? 120.0 : 60.0 }
    expected_weights.each_with_index do |w, i|
      assert_in_delta w, weights[i], 0.01
    end

    assert_redirected_to day_path(date: "2026-04-21")
    assert_equal "Template logged.", flash[:notice]
  end

  test "log returns 404 for other user template" do
    other_user = create(:user)
    template = create(:meal_template, user: other_user)

    login(@account)
    post log_meal_template_path(template), params: {
      date: "2026-04-21",
      meal: "breakfast"
    }
    assert_response :not_found
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
