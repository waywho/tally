class Recipe < ApplicationRecord
  belongs_to :user
  belongs_to :food
  has_many :recipe_ingredients, dependent: :destroy

  accepts_nested_attributes_for :recipe_ingredients, allow_destroy: true,
    reject_if: proc { |attrs| attrs["food_id"].blank? }

  validates :name, presence: true, length: { maximum: 255 }
  validates :servings_in_recipe, presence: true, numericality: { greater_than: 0 }

  def compute_nutrition!
    total_weight = recipe_ingredients.sum(:weight)
    return if total_weight.zero?

    nutrients = { calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0 }

    recipe_ingredients.includes(:food).each do |ingredient|
      nutrients.each_key do |nutrient|
        nutrients[nutrient] += ingredient.food.public_send(nutrient) * ingredient.weight / 100
      end
    end

    food.update!(
      name: name,
      calories: nutrients[:calories] / total_weight * 100,
      protein: nutrients[:protein] / total_weight * 100,
      carbs: nutrients[:carbs] / total_weight * 100,
      fat: nutrients[:fat] / total_weight * 100,
      fiber: nutrients[:fiber] / total_weight * 100,
      serving_size: total_weight / servings_in_recipe,
      serving_label: "1 serving",
      source: :user,
      creator: user
    )
  end
end
