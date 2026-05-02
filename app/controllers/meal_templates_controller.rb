class MealTemplatesController < ApplicationController
  before_action :require_authentication
  before_action :set_meal_template, only: [ :destroy, :log ]

  def index
    @meal_templates = current_user.meal_templates
      .includes(meal_template_items: :food)
      .order(updated_at: :desc)
  end

  def new
    @meal_template = MealTemplate.new
    @date = params[:date]
    @meal = params[:meal]

    if @date.present? && @meal.present?
      @entries = current_user.food_log_entries
        .includes(:food)
        .where(logged_on: @date.to_date, meal: @meal)
      @meal_template.name = "#{@meal.capitalize} — #{@date.to_date.strftime("%b %-d")}"
    else
      @entries = []
    end
  end

  def create
    @meal_template = current_user.meal_templates.build(meal_template_params)
    @date = params[:date]
    @meal = params[:meal]

    entries = current_user.food_log_entries
      .where(logged_on: @date.to_date, meal: @meal)

    entries.each do |entry|
      @meal_template.meal_template_items.build(
        food_id: entry.food_id,
        weight: entry.weight
      )
    end

    if @meal_template.save
      redirect_to meal_templates_path, notice: t("flash.template_saved")
    else
      @entries = current_user.food_log_entries
        .includes(:food)
        .where(logged_on: @date.to_date, meal: @meal)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @meal_template.destroy!
    redirect_to meal_templates_path, notice: t("flash.template_deleted")
  end

  def log
    date = params[:date].to_date
    meal = params[:meal]

    @meal_template.meal_template_items.each do |item|
      current_user.food_log_entries.create!(
        food_id: item.food_id,
        weight: item.weight,
        meal: meal,
        logged_on: date
      )
    end

    redirect_to day_path(date: date.iso8601), notice: t("flash.template_logged")
  end

  private

  def set_meal_template
    @meal_template = current_user.meal_templates.find(params[:id])
  end

  def meal_template_params
    params.require(:meal_template).permit(:name)
  end
end
