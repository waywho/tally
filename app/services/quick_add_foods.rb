class QuickAddFoods
  def self.call(user:, meal:, limit: 10)
    new(user: user, meal: meal, limit: limit).call
  end

  def initialize(user:, meal:, limit: 10)
    @user = user
    @meal = meal
    @limit = limit
  end

  def call
    meal_food_ids = ranked_food_ids(scope: @user.food_log_entries.where(meal: @meal), limit: @limit)

    if meal_food_ids.size < @limit
      remaining = @limit - meal_food_ids.size
      global_food_ids = ranked_food_ids(
        scope: @user.food_log_entries.where.not(food_id: meal_food_ids),
        limit: remaining
      )
      food_ids = meal_food_ids + global_food_ids
    else
      food_ids = meal_food_ids
    end

    return [] if food_ids.empty?

    foods_by_id = Food.where(id: food_ids).index_by(&:id)
    food_ids.filter_map { |id| foods_by_id[id] }
  end

  private

  def ranked_food_ids(scope:, limit:)
    scope
      .group(:food_id)
      .order(Arel.sql("COUNT(*) DESC, MAX(logged_on) DESC"))
      .limit(limit)
      .pluck(:food_id)
  end
end
