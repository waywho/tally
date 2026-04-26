class MealPickersController < ApplicationController
  before_action :require_authentication

  def show
    @current_meal = params[:meal]
    @date = params[:date]
    @query = params[:q]
  end
end
