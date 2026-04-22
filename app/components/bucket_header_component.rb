class BucketHeaderComponent < ViewComponent::Base
  def initialize(meal:, subtotal:, add_path:, protein: 0, carbs: 0, fat: 0, fiber: 0)
    @meal = meal
    @subtotal = subtotal
    @add_path = add_path
    @protein = protein
    @carbs = carbs
    @fat = fat
    @fiber = fiber
  end
end
