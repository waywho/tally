require_relative "error"

module Off
  class Client
    def search(query, page: 1, per_page: 20)
      results = Openfoodfacts::Product.search(query, locale: "world", page_size: per_page, page: page)

      (results || []).map { |product| build_result(product) }
    rescue Off::Error
      raise
    rescue StandardError => e
      raise ApiError, "Open Food Facts API error: #{e.message}"
    end

    def fetch(barcode)
      product = Openfoodfacts::Product.get(barcode, locale: "world")

      raise ProductNotFoundError, barcode if product.nil? || product.product_name.blank?

      build_result(product)
    rescue Off::Error
      raise
    rescue StandardError => e
      raise ApiError, "Open Food Facts API error: #{e.message}"
    end

    def persist(food_result)
      food = Food.find_or_initialize_by(source: :off, external_id: food_result.barcode)
      food.update!(
        name: food_result.name,
        brand: food_result.brand,
        calories: food_result.calories,
        protein: food_result.protein,
        carbs: food_result.carbs,
        fat: food_result.fat,
        fiber: food_result.fiber,
        serving_size: food_result.serving_size,
        serving_label: food_result.serving_label,
        verified_at: Time.current
      )
      food
    end

    private

    def build_result(product)
      nutrients = NutrientMapper.extract(product.nutriments&.to_hash)

      FoodResult.new(
        barcode: product.code,
        name: product.product_name,
        brand: product.brands,
        serving_size: product.serving_quantity&.to_f,
        serving_label: product.serving_size,
        **nutrients
      )
    end
  end
end
