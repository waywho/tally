require "test_helper"

class RecipeIngredientTest < ActiveSupport::TestCase
  test "factory is valid" do
    ingredient = build(:recipe_ingredient)
    assert ingredient.valid?, ingredient.errors.full_messages.join(", ")
  end

  test "invalid without food" do
    ingredient = build(:recipe_ingredient, food: nil)
    assert_not ingredient.valid?
    assert_includes ingredient.errors[:food], "must exist"
  end

  test "invalid without weight" do
    ingredient = build(:recipe_ingredient, weight: nil)
    assert_not ingredient.valid?
    assert_includes ingredient.errors[:weight], "can't be blank"
  end

  test "invalid with weight zero" do
    ingredient = build(:recipe_ingredient, weight: 0)
    assert_not ingredient.valid?
    assert ingredient.errors[:weight].any?
  end

  test "invalid with negative weight" do
    ingredient = build(:recipe_ingredient, weight: -5)
    assert_not ingredient.valid?
    assert ingredient.errors[:weight].any?
  end

  test "belongs to recipe" do
    ingredient = create(:recipe_ingredient)
    assert_instance_of Recipe, ingredient.recipe
  end

  test "belongs to food" do
    ingredient = create(:recipe_ingredient)
    assert_instance_of Food, ingredient.food
  end
end
