class DaysController < ApplicationController
  before_action :require_authentication

  def show
    @date = params[:date]&.to_date || Date.current

    entries = current_user.food_log_entries
      .where(logged_on: @date)
      .includes(:food)
      .order(:created_at)

    @entries_by_meal = FoodLogEntry.meals.keys.index_with { |_meal| [] }
    entries.each { |entry| @entries_by_meal[entry.meal] << entry }

    @meal_totals = @entries_by_meal.transform_values do |meal_entries|
      {
        calories: meal_entries.sum(&:calories),
        protein: meal_entries.sum(&:protein),
        carbs: meal_entries.sum(&:carbs),
        fat: meal_entries.sum(&:fat),
        fiber: meal_entries.sum(&:fiber)
      }
    end

    @daily_totals = {
      calories: @meal_totals.values.sum { |t| t[:calories] },
      protein: @meal_totals.values.sum { |t| t[:protein] },
      carbs: @meal_totals.values.sum { |t| t[:carbs] },
      fat: @meal_totals.values.sum { |t| t[:fat] },
      fiber: @meal_totals.values.sum { |t| t[:fiber] },
      target_calories: current_user.daily_calorie_target,
      target_protein: current_user.protein_target,
      target_carbs: current_user.carbs_target,
      target_fat: current_user.fat_target,
      target_fiber: current_user.fiber_target
    }
  end
end
