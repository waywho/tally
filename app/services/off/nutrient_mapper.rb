module Off
  class NutrientMapper
    FIELD_MAP = {
      "energy-kcal_100g" => :calories,
      "proteins_100g" => :protein,
      "carbohydrates_100g" => :carbs,
      "fat_100g" => :fat,
      "fiber_100g" => :fiber
    }.freeze

    DEFAULTS = FIELD_MAP.values.index_with { 0.0 }.freeze

    def self.extract(nutriments)
      return DEFAULTS.dup if nutriments.nil?

      nutrients = DEFAULTS.dup

      FIELD_MAP.each do |off_key, our_key|
        value = nutriments[off_key]
        nutrients[our_key] = value.to_f if value
      end

      nutrients
    end
  end
end
