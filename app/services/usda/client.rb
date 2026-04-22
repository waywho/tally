require_relative "error"

module Usda
  class Client
    BASE_URL = "https://api.nal.usda.gov/fdc/v1".freeze
    DATA_TYPES = ["Foundation", "SR Legacy"].freeze

    def initialize(api_key: Rails.application.credentials.usda_api_key)
      @api_key = api_key
      raise ConfigError, "USDA API key not configured" if @api_key.blank?
    end

    def search(query, page: 1, per_page: 20)
      body = {
        query: query,
        dataType: DATA_TYPES,
        pageSize: per_page,
        pageNumber: page
      }

      response = post("/foods/search", body)
      data = JSON.parse(response.body)

      (data["foods"] || []).map { |food| build_result_from_search(food) }
    rescue RestClient::TooManyRequests
      raise RateLimitError
    rescue RestClient::Exception => e
      raise ApiError.new("USDA API error: #{e.message}", status_code: e.http_code)
    end

    def fetch(fdc_id)
      response = get("/food/#{fdc_id}")
      data = JSON.parse(response.body)

      build_result_from_detail(data)
    rescue RestClient::TooManyRequests
      raise RateLimitError
    rescue RestClient::Exception => e
      raise ApiError.new("USDA API error: #{e.message}", status_code: e.http_code)
    end

    def persist(food_result)
      food = Food.find_or_initialize_by(source: :usda, external_id: food_result.fdc_id)
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

    def post(path, body)
      RestClient.post(
        "#{BASE_URL}#{path}?api_key=#{@api_key}",
        body.to_json,
        content_type: :json, accept: :json
      )
    end

    def get(path)
      RestClient.get(
        "#{BASE_URL}#{path}?api_key=#{@api_key}",
        accept: :json
      )
    end

    def build_result_from_search(food_data)
      nutrients = NutrientMapper.extract(food_data["foodNutrients"] || [])

      FoodResult.new(
        fdc_id: food_data["fdcId"].to_s,
        name: food_data["description"],
        brand: food_data["brandName"],
        serving_size: nil,
        serving_label: nil,
        **nutrients
      )
    end

    def build_result_from_detail(food_data)
      raw_nutrients = (food_data["foodNutrients"] || []).map do |fn|
        { "nutrientId" => fn.dig("nutrient", "id"), "value" => fn["amount"] }
      end
      nutrients = NutrientMapper.extract(raw_nutrients)

      portion = food_data.dig("foodPortions", 0)
      serving_size = food_data["servingSize"] || portion&.dig("gramWeight")
      serving_label = portion&.dig("portionDescription")

      FoodResult.new(
        fdc_id: food_data["fdcId"].to_s,
        name: food_data["description"],
        brand: food_data["brandName"],
        serving_size: serving_size,
        serving_label: serving_label,
        **nutrients
      )
    end
  end
end
