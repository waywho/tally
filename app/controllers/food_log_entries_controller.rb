class FoodLogEntriesController < ApplicationController
  before_action :require_authentication
  before_action :set_date
  before_action :set_entry, only: [:edit, :update, :destroy]

  def create
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
    params.require(:food_log_entry).permit(:food_id, :meal, :quantity_g)
  end
end
