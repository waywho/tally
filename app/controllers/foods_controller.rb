class FoodsController < ApplicationController
  before_action :require_authentication

  def index
    @query = params[:q].to_s.strip
    @results = if @query.length >= 3
      FoodSearch.call(@query)
    else
      []
    end
  end
end
