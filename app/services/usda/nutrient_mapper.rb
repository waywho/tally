module Usda
  class NutrientMapper
    NUTRIENT_IDS = {
      1008 => :calories,
      1003 => :protein,
      1005 => :carbs,
      1004 => :fat,
      1079 => :fiber
    }.freeze

    DEFAULTS = NUTRIENT_IDS.values.index_with { 0.0 }.freeze

    def self.extract(food_nutrients)
      nutrients = DEFAULTS.dup

      food_nutrients.each do |nutrient|
        key = NUTRIENT_IDS[nutrient["nutrientId"]]
        nutrients[key] = nutrient["value"].to_f if key
      end

      nutrients
    end
  end
end
