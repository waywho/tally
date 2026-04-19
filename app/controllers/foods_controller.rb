class FoodsController < ApplicationController
  before_action :require_authentication

  def index
    @query = params[:q].to_s.strip
    @results = if @query.length >= 3
      FoodSearch.call(@query, user: current_user)
    else
      []
    end
  end
end
