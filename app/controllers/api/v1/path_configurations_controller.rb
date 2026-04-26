class Api::V1::PathConfigurationsController < ApplicationController
  skip_before_action :ensure_onboarded

  def show
    render json: Rails.root.join("config/path-configuration.json").read,
           content_type: "application/json"
  end
end
