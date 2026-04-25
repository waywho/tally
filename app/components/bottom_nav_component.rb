# frozen_string_literal: true

class BottomNavComponent < ViewComponent::Base
  def initialize(current_path:, viewed_date: nil)
    @current_path = current_path
    @viewed_date = viewed_date
  end

  def add_path
    helpers.foods_path(meal: MealInferrer.call, date: (@viewed_date || Date.current).iso8601)
  end

  def today_active?
    @current_path.start_with?("/today") || @current_path.match?(%r{\A/days/})
  end

  def search_active?
    @current_path == "/foods" || @current_path.start_with?("/foods?")
  end

  def recipes_active?
    @current_path.start_with?("/recipes")
  end

  def profile_active?
    @current_path.start_with?("/settings")
  end
end
