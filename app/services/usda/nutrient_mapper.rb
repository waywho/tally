module Usda
  class NutrientMapper
    # USDA reports energy under multiple nutrient IDs depending on the data
    # source. Foundation/SR Legacy records typically use 1008 ("Energy"), but
    # newer Foundation records may only return 2047/2048 ("Energy (Atwater
    # General/Specific Factors)"). Without these fallbacks, foods like
    # "Apples, fuji, with skin, raw" show 0 kcal in the bottom sheet.
    ENERGY_IDS = [ 1008, 2047, 2048 ].freeze

    NUTRIENT_IDS = {
      1003 => :protein,
      1005 => :carbs,
      1004 => :fat,
      1079 => :fiber
    }.freeze

    DEFAULTS = (NUTRIENT_IDS.values + [ :calories ]).index_with { 0.0 }.freeze

    def self.extract(food_nutrients)
      nutrients = DEFAULTS.dup
      energy_by_id = {}

      food_nutrients.each do |nutrient|
        id = nutrient["nutrientId"]
        value = nutrient["value"].to_f

        if ENERGY_IDS.include?(id)
          energy_by_id[id] = value
        elsif (key = NUTRIENT_IDS[id])
          nutrients[key] = value
        end
      end

      # Prefer 1008, then 2047, then 2048 — first non-zero wins.
      nutrients[:calories] = ENERGY_IDS
        .lazy
        .filter_map { |id| energy_by_id[id] }
        .find { |v| v > 0 } || 0.0

      nutrients
    end
  end
end
