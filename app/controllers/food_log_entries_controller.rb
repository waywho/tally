class FoodLogEntriesController < ApplicationController
  before_action :require_authentication
  before_action :set_date
  before_action :set_entry, only: [:edit, :update, :destroy]

  def create
    food_params = params.require(:food_log_entry)

    if food_params[:food_id].present?
      # Normal flow: food already exists in DB
    elsif food_params[:usda_fdc_id].present?
      # USDA transient result: persist the food first
      food_result = Usda::FoodResult.new(
        fdc_id: food_params[:usda_fdc_id],
        name: food_params[:usda_name],
        brand: food_params[:usda_brand],
        calories: food_params[:usda_calories],
        protein: food_params[:usda_protein],
        carbs: food_params[:usda_carbs],
        fat: food_params[:usda_fat],
        fiber: food_params[:usda_fiber]
      )
      food = Usda::Client.new.persist(food_result)
      params[:food_log_entry][:food_id] = food.id
    else
      head :unprocessable_entity
      return
    end

    @entry = current_user.food_log_entries.build(entry_params)
    @entry.logged_on = @date

    if @entry.save
      redirect_to day_path(date: @date.iso8601), notice: t("flash.entry_created")
    else
      head :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @entry.update(entry_params)
      redirect_to day_path(date: @entry.logged_on.iso8601), notice: t("flash.entry_updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @entry.destroy!
    redirect_to day_path(date: @entry.logged_on.iso8601), notice: t("flash.entry_deleted")
  end

  private

  def set_date
    @date = params[:day_date].to_date
  end

  def set_entry
    @entry = current_user.food_log_entries.find(params[:id])
  end

  def entry_params
    params.require(:food_log_entry).permit(:food_id, :meal, :weight)
  end
end
