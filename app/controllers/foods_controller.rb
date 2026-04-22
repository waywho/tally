class FoodsController < ApplicationController
  before_action :require_authentication
  before_action :set_food, only: [:edit, :update, :destroy]

  def index
    @query = params[:q].to_s.strip
    @results = if @query.length >= 3
      FoodSearch.call(@query, user: current_user)
    else
      []
    end
    @meal = params[:meal]
    @date = params[:date]
    @meal_templates = if @meal.present? && @date.present?
      current_user.meal_templates
        .includes(meal_template_items: :food)
        .order(updated_at: :desc)
    else
      []
    end
    @quick_add_foods = if @meal.present? && @query.length < 3
      QuickAddFoods.call(user: current_user, meal: @meal)
    else
      []
    end
    @quick_add_last_weights = if @quick_add_foods.any?
      current_user.food_log_entries
        .where(food_id: @quick_add_foods.map(&:id))
        .select("DISTINCT ON (food_id) food_id, weight")
        .order("food_id, created_at DESC")
        .to_a
        .to_h { |e| [e.food_id, e.weight] }
    else
      {}
    end
    @meal_totals = if @meal.present? && @date.present?
      date = Date.parse(@date) rescue nil
      entries = date ? current_user.food_log_entries.where(logged_on: date, meal: @meal) : []
      {
        calories: entries.sum(&:calories),
        protein: entries.sum(&:protein),
        carbs: entries.sum(&:carbs),
        fat: entries.sum(&:fat),
        fiber: entries.sum(&:fiber)
      }
    end
  end

  def new
    @food = Food.new(name: params[:name])
  end

  def create
    @food = current_user.created_foods.build(food_params)
    @food.source = :user

    if @food.save
      redirect_to foods_path(q: @food.name), notice: t("flash.food_created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @food.update(food_params)
      redirect_to foods_path(q: @food.name), notice: t("flash.food_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @food.destroy!
    redirect_to foods_path, notice: t("flash.food_deleted")
  end

  private

  def set_food
    @food = current_user.created_foods.find(params[:id])
  end

  def food_params
    params.require(:food).permit(:name, :brand, :calories, :protein, :carbs, :fat, :fiber, :barcode, :serving_size, :serving_label)
  end
end
