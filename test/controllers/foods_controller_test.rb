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

  # Meal context
  test "index shows meal context header when meal param present" do
    login(@account)
    get foods_path(meal: "breakfast", date: "2026-04-19")

    assert_response :success
    assert_select "[data-meal-context]", /Adding to Breakfast/
    assert_select "[data-meal-context]", /Apr 19/
  end

  test "index does not show meal context header without meal param" do
    login(@account)
    get foods_path

    assert_response :success
    assert_select "[data-meal-context]", count: 0
  end

  test "index passes meal context to results" do
    5.times { |i| create(:food, name: "Chicken breast #{i}", source: :off, external_id: "ctx-#{i}") }

    login(@account)
    get foods_path(q: "chicken", meal: "lunch", date: "2026-04-19")

    assert_response :success
    assert_select "[data-food-result][data-meal-context-active]"
  end

  # New
  test "new renders form when authenticated" do
    login(@account)
    get new_food_path
    assert_response :success
    assert_select "form[action='#{foods_path}']"
    assert_select "input[name='food[name]']"
    assert_select "input[name='food[calories]']"
  end

  test "new redirects when not authenticated" do
    get new_food_path
    assert_response :redirect
  end

  test "new pre-fills name from query param" do
    login(@account)
    get new_food_path(name: "My special food")
    assert_response :success
    assert_select "input[name='food[name]'][value='My special food']"
  end

  # Create
  test "create saves food with source user and creator" do
    login(@account)

    assert_difference "Food.count", 1 do
      post foods_path, params: {
        food: {
          name: "Homemade pasta",
          calories: 200,
          protein: 8,
          carbs: 35,
          fat: 4,
          fiber: 2,
          brand: "Mom's kitchen",
          barcode: "",
          serving_size: 150,
          serving_label: "1 plate"
        }
      }
    end

    food = Food.last
    assert food.user?
    assert_equal @user.id, food.creator_id
    assert_equal "Homemade pasta", food.name
    assert_redirected_to foods_path(q: "Homemade pasta")
  end

  test "create with invalid params re-renders form" do
    login(@account)

    assert_no_difference "Food.count" do
      post foods_path, params: {
        food: { name: "", calories: -1 }
      }
    end

    assert_response :unprocessable_entity
    assert_select "p.field-error"
  end

  # Edit
  test "edit renders form for creator" do
    login(@account)
    food = create(:food, :user_created, creator: @user, name: "My food")

    get edit_food_path(food)
    assert_response :success
    assert_select "input[name='food[name]'][value='My food']"
  end

  test "edit returns 404 for non-creator" do
    other_user = create(:user)
    food = create(:food, :user_created, creator: other_user, name: "Other food")

    login(@account)
    get edit_food_path(food)
    assert_response :not_found
  end

  # Update
  test "update saves changes for creator" do
    login(@account)
    food = create(:food, :user_created, creator: @user, name: "Old name")

    patch food_path(food), params: { food: { name: "New name" } }

    assert_redirected_to foods_path(q: "New name")
    assert_equal "New name", food.reload.name
  end

  test "update returns 404 for non-creator" do
    other_user = create(:user)
    food = create(:food, :user_created, creator: other_user)

    login(@account)
    patch food_path(food), params: { food: { name: "Hacked" } }
    assert_response :not_found
  end

  # Destroy
  test "destroy removes food for creator" do
    login(@account)
    food = create(:food, :user_created, creator: @user)

    assert_difference "Food.count", -1 do
      delete food_path(food)
    end

    assert_redirected_to foods_path
    assert_equal "Food deleted.", flash[:notice]
  end

  test "destroy returns 404 for non-creator" do
    other_user = create(:user)
    food = create(:food, :user_created, creator: other_user)

    login(@account)
    delete food_path(food)
    assert_response :not_found
  end

  # Templates section
  test "index shows templates section when meal context and templates exist" do
    food = create(:food, name: "Eggs", calories: 150)
    template = create(:meal_template, user: @user, name: "Quick Breakfast")
    create(:meal_template_item, meal_template: template, food: food, weight: 100)

    login(@account)
    get foods_path(meal: "breakfast", date: "2026-04-21")

    assert_response :success
    assert_select "[data-templates-section]"
    assert_select "[data-templates-section]", text: /Quick Breakfast/
  end

  test "index does not show templates section without meal param" do
    template = create(:meal_template, user: @user, name: "Quick Breakfast")
    create(:meal_template_item, meal_template: template)

    login(@account)
    get foods_path

    assert_response :success
    assert_select "[data-templates-section]", count: 0
  end

  test "index does not show templates section when user has no templates" do
    login(@account)
    get foods_path(meal: "breakfast", date: "2026-04-21")

    assert_response :success
    assert_select "[data-templates-section]", count: 0
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
