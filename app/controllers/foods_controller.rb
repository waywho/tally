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
