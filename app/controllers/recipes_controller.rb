class RecipesController < ApplicationController
  before_action :require_authentication
  before_action :set_recipe, only: [ :show, :edit, :update, :destroy ]

  def index
    @recipes = current_user.recipes.includes(:food).order(updated_at: :desc)
  end

  def show
    @recipe_ingredients = @recipe.recipe_ingredients.includes(:food)
  end

  def new
    @recipe = Recipe.new
    @recipe.recipe_ingredients.build
    @foods = available_foods
  end

  def create
    generated_food = current_user.created_foods.build(
      name: recipe_params[:name],
      source: :user,
      calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0
    )

    @recipe = current_user.recipes.build(recipe_params)
    @recipe.food = generated_food

    if generated_food.save && @recipe.save
      @recipe.compute_nutrition!
      redirect_to recipe_path(@recipe), notice: t("flash.recipe_created")
    else
      @recipe.errors.merge!(generated_food.errors) unless generated_food.valid?
      @foods = available_foods
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @foods = available_foods
  end

  def update
    if @recipe.update(recipe_params)
      @recipe.compute_nutrition!
      redirect_to recipe_path(@recipe), notice: t("flash.recipe_updated")
    else
      @foods = available_foods
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    generated_food = @recipe.food
    @recipe.destroy!
    generated_food.destroy!
    redirect_to recipes_path, notice: t("flash.recipe_deleted")
  end

  private

  def set_recipe
    @recipe = current_user.recipes.find(params[:id])
  end

  def recipe_params
    params.require(:recipe).permit(
      :name, :servings_in_recipe,
      recipe_ingredients_attributes: [ :id, :food_id, :weight, :_destroy ]
    )
  end

  def available_foods
    Food.where.not(source: :user).or(Food.where(source: :user, creator_id: current_user.id)).order(:name)
  end
end
