require "test_helper"

class RecipesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = create(:account)
    @user = create(:user, account: @account)
  end

  # Authentication
  test "index redirects when not authenticated" do
    get recipes_path
    assert_response :redirect
  end

  # Index
  test "index lists current user recipes" do
    generated_food = create(:food, :user_created, creator: @user)
    recipe = create(:recipe, user: @user, food: generated_food, name: "My Recipe")

    other_user = create(:user)
    other_food = create(:food, :user_created, creator: other_user)
    create(:recipe, user: other_user, food: other_food, name: "Other Recipe")

    login(@account)
    get recipes_path

    assert_response :success
    assert_select "[data-recipe]", count: 1
    assert_select "[data-recipe]", text: /My Recipe/
  end

  # Show
  test "show displays recipe with ingredients" do
    generated_food = create(:food, :user_created, creator: @user)
    recipe = create(:recipe, user: @user, food: generated_food, name: "Pasta Bake")
    ingredient_food = create(:food, name: "Pasta")
    create(:recipe_ingredient, recipe: recipe, food: ingredient_food, weight: 200)

    login(@account)
    get recipe_path(recipe)

    assert_response :success
    assert_select "h1", text: /Pasta Bake/
  end

  test "show returns 404 for non-owner" do
    other_user = create(:user)
    other_food = create(:food, :user_created, creator: other_user)
    recipe = create(:recipe, user: other_user, food: other_food)

    login(@account)
    get recipe_path(recipe)
    assert_response :not_found
  end

  # New
  test "new renders form when authenticated" do
    login(@account)
    get new_recipe_path

    assert_response :success
    assert_select "form[action='#{recipes_path}']"
    assert_select "input[name='recipe[name]']"
    assert_select "input[name='recipe[servings_in_recipe]']"
  end

  test "new redirects when not authenticated" do
    get new_recipe_path
    assert_response :redirect
  end

  # Create
  test "create saves recipe with ingredients and generates food" do
    ingredient_food = create(:food, name: "Chicken", calories: 200, protein: 25, carbs: 0, fat: 10, fiber: 0)

    login(@account)

    assert_difference ["Recipe.count", "Food.count"], 1 do
      post recipes_path, params: {
        recipe: {
          name: "Grilled Chicken",
          servings_in_recipe: 2,
          recipe_ingredients_attributes: {
            "0" => { food_id: ingredient_food.id, weight: 300 }
          }
        }
      }
    end

    recipe = Recipe.last
    assert_equal "Grilled Chicken", recipe.name
    assert_equal 2, recipe.servings_in_recipe
    assert_equal 1, recipe.recipe_ingredients.count
    assert_equal 300, recipe.recipe_ingredients.first.weight

    # Verify generated food has computed nutrition
    generated_food = recipe.food
    assert generated_food.user?
    assert_equal @user.id, generated_food.creator_id
    assert_equal "Grilled Chicken", generated_food.name
    assert_in_delta 200.0, generated_food.calories, 0.01
    assert_in_delta 150.0, generated_food.serving_size, 0.01

    assert_redirected_to recipe_path(recipe)
  end

  test "create with invalid params re-renders form" do
    login(@account)

    assert_no_difference "Recipe.count" do
      post recipes_path, params: {
        recipe: { name: "", servings_in_recipe: 0 }
      }
    end

    assert_response :unprocessable_entity
  end

  # Edit
  test "edit renders form for owner" do
    generated_food = create(:food, :user_created, creator: @user)
    recipe = create(:recipe, user: @user, food: generated_food, name: "My Recipe")

    login(@account)
    get edit_recipe_path(recipe)

    assert_response :success
    assert_select "input[name='recipe[name]'][value='My Recipe']"
  end

  test "edit returns 404 for non-owner" do
    other_user = create(:user)
    other_food = create(:food, :user_created, creator: other_user)
    recipe = create(:recipe, user: other_user, food: other_food)

    login(@account)
    get edit_recipe_path(recipe)
    assert_response :not_found
  end

  # Update
  test "update saves changes and recalculates nutrition" do
    generated_food = create(:food, :user_created, creator: @user, calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0)
    recipe = create(:recipe, user: @user, food: generated_food, name: "Old Name", servings_in_recipe: 2)
    ingredient_food = create(:food, calories: 100, protein: 10, carbs: 20, fat: 5, fiber: 2)
    ingredient = create(:recipe_ingredient, recipe: recipe, food: ingredient_food, weight: 200)

    login(@account)
    patch recipe_path(recipe), params: {
      recipe: {
        name: "New Name",
        servings_in_recipe: 4,
        recipe_ingredients_attributes: {
          "0" => { id: ingredient.id, food_id: ingredient_food.id, weight: 400 }
        }
      }
    }

    assert_redirected_to recipe_path(recipe)
    recipe.reload
    assert_equal "New Name", recipe.name
    assert_equal 4, recipe.servings_in_recipe
    assert_equal 400, recipe.recipe_ingredients.first.weight

    generated_food.reload
    assert_equal "New Name", generated_food.name
    assert_in_delta 100.0, generated_food.serving_size, 0.01
  end

  test "update returns 404 for non-owner" do
    other_user = create(:user)
    other_food = create(:food, :user_created, creator: other_user)
    recipe = create(:recipe, user: other_user, food: other_food)

    login(@account)
    patch recipe_path(recipe), params: { recipe: { name: "Hacked" } }
    assert_response :not_found
  end

  # Destroy
  test "destroy removes recipe and generated food" do
    generated_food = create(:food, :user_created, creator: @user)
    recipe = create(:recipe, user: @user, food: generated_food)

    login(@account)

    assert_difference "Recipe.count", -1 do
      assert_difference "Food.count", -1 do
        delete recipe_path(recipe)
      end
    end

    assert_redirected_to recipes_path
    assert_equal "Recipe deleted.", flash[:notice]
  end

  test "destroy returns 404 for non-owner" do
    other_user = create(:user)
    other_food = create(:food, :user_created, creator: other_user)
    recipe = create(:recipe, user: other_user, food: other_food)

    login(@account)
    delete recipe_path(recipe)
    assert_response :not_found
  end

  private

  def login(account)
    post "/login", params: { email: account.email, password: "password" }
  end
end
