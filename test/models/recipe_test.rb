require "test_helper"

class RecipeTest < ActiveSupport::TestCase
  test "factory is valid" do
    recipe = build(:recipe)
    assert recipe.valid?, recipe.errors.full_messages.join(", ")
  end

  # Validations
  test "invalid without name" do
    recipe = build(:recipe, name: nil)
    assert_not recipe.valid?
    assert_includes recipe.errors[:name], "can't be blank"
  end

  test "invalid with name over 255 characters" do
    recipe = build(:recipe, name: "a" * 256)
    assert_not recipe.valid?
    assert recipe.errors[:name].any?
  end

  test "invalid without servings_in_recipe" do
    recipe = build(:recipe, servings_in_recipe: nil)
    assert_not recipe.valid?
    assert_includes recipe.errors[:servings_in_recipe], "can't be blank"
  end

  test "invalid with servings_in_recipe zero" do
    recipe = build(:recipe, servings_in_recipe: 0)
    assert_not recipe.valid?
    assert recipe.errors[:servings_in_recipe].any?
  end

  test "invalid with negative servings_in_recipe" do
    recipe = build(:recipe, servings_in_recipe: -1)
    assert_not recipe.valid?
    assert recipe.errors[:servings_in_recipe].any?
  end

  # Associations
  test "belongs to user" do
    recipe = create(:recipe)
    assert_instance_of User, recipe.user
  end

  test "belongs to food" do
    recipe = create(:recipe)
    assert_instance_of Food, recipe.food
  end

  test "has many recipe_ingredients with dependent destroy" do
    recipe = create(:recipe)
    create(:recipe_ingredient, recipe: recipe)
    create(:recipe_ingredient, recipe: recipe)

    assert_equal 2, recipe.recipe_ingredients.count

    assert_difference "RecipeIngredient.count", -2 do
      recipe.destroy!
    end
  end

  test "accepts nested attributes for recipe_ingredients" do
    recipe = create(:recipe)
    food = create(:food)

    recipe.update!(recipe_ingredients_attributes: [
      { food_id: food.id, weight: 200 }
    ])

    assert_equal 1, recipe.recipe_ingredients.count
    assert_equal 200, recipe.recipe_ingredients.first.weight
  end

  test "accepts nested attributes with allow_destroy" do
    recipe = create(:recipe)
    ingredient = create(:recipe_ingredient, recipe: recipe)

    recipe.update!(recipe_ingredients_attributes: [
      { id: ingredient.id, _destroy: true }
    ])

    assert_equal 0, recipe.recipe_ingredients.count
  end

  test "rejects nested attributes when food_id is blank" do
    recipe = create(:recipe)

    recipe.update!(recipe_ingredients_attributes: [
      { food_id: "", weight: 200 }
    ])

    assert_equal 0, recipe.recipe_ingredients.count
  end

  # compute_nutrition!
  test "compute_nutrition! calculates per-100g values from ingredients" do
    user = create(:user)
    generated_food = create(:food, :user_created, creator: user, name: "placeholder")
    recipe = create(:recipe, user: user, food: generated_food, name: "Test Recipe", servings_in_recipe: 2)

    # Ingredient 1: 200g of food with 250 cal/100g, 10g protein/100g
    food_a = create(:food, calories: 250, protein: 10, carbs: 30, fat: 12, fiber: 3)
    create(:recipe_ingredient, recipe: recipe, food: food_a, weight: 200)

    # Ingredient 2: 100g of food with 100 cal/100g, 20g protein/100g
    food_b = create(:food, calories: 100, protein: 20, carbs: 10, fat: 5, fiber: 1)
    create(:recipe_ingredient, recipe: recipe, food: food_b, weight: 100)

    recipe.compute_nutrition!
    generated_food.reload

    # total_weight = 300g
    # total_calories = (250 * 200/100) + (100 * 100/100) = 500 + 100 = 600
    # per_100g_calories = 600 / 300 * 100 = 200
    assert_in_delta 200.0, generated_food.calories, 0.01

    # total_protein = (10 * 200/100) + (20 * 100/100) = 20 + 20 = 40
    # per_100g_protein = 40 / 300 * 100 = 13.33
    assert_in_delta 13.33, generated_food.protein, 0.01

    # total_carbs = (30 * 200/100) + (10 * 100/100) = 60 + 10 = 70
    # per_100g_carbs = 70 / 300 * 100 = 23.33
    assert_in_delta 23.33, generated_food.carbs, 0.01

    # total_fat = (12 * 200/100) + (5 * 100/100) = 24 + 5 = 29
    # per_100g_fat = 29 / 300 * 100 = 9.67
    assert_in_delta 9.67, generated_food.fat, 0.01

    # total_fiber = (3 * 200/100) + (1 * 100/100) = 6 + 1 = 7
    # per_100g_fiber = 7 / 300 * 100 = 2.33
    assert_in_delta 2.33, generated_food.fiber, 0.01
  end

  test "compute_nutrition! sets serving_size based on total_weight and servings_in_recipe" do
    user = create(:user)
    generated_food = create(:food, :user_created, creator: user, name: "placeholder")
    recipe = create(:recipe, user: user, food: generated_food, name: "Serving Test", servings_in_recipe: 4)

    food_a = create(:food, calories: 100, protein: 5, carbs: 20, fat: 3, fiber: 1)
    create(:recipe_ingredient, recipe: recipe, food: food_a, weight: 400)

    recipe.compute_nutrition!
    generated_food.reload

    # total_weight = 400, servings = 4 => serving_size = 100
    assert_in_delta 100.0, generated_food.serving_size, 0.01
    assert_equal "1 serving", generated_food.serving_label
  end

  test "compute_nutrition! updates the food name to match recipe name" do
    user = create(:user)
    generated_food = create(:food, :user_created, creator: user, name: "old name")
    recipe = create(:recipe, user: user, food: generated_food, name: "My Great Recipe")

    food_a = create(:food, calories: 100, protein: 5, carbs: 20, fat: 3, fiber: 1)
    create(:recipe_ingredient, recipe: recipe, food: food_a, weight: 100)

    recipe.compute_nutrition!
    generated_food.reload

    assert_equal "My Great Recipe", generated_food.name
    assert generated_food.user?
    assert_equal user.id, generated_food.creator_id
  end

  test "compute_nutrition! does nothing when total_weight is zero" do
    user = create(:user)
    generated_food = create(:food, :user_created, creator: user, name: "original", calories: 999)
    recipe = create(:recipe, user: user, food: generated_food, name: "Empty Recipe")

    recipe.compute_nutrition!
    generated_food.reload

    assert_equal 999, generated_food.calories
  end
end
