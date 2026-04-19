# frozen_string_literal: true

class FlashComponent < ViewComponent::Base
  attr_reader :notice, :alert

  def initialize(notice: nil, alert: nil)
    @notice = notice
    @alert = alert
  end

  def call
    content_tag(:div, class: "fixed top-0 left-0 w-full py-6 px-8", **data_attributes) do
      safe_join([
        (tag.div(notice, class: "mb-2 p-3 bg-primary-tint text-primary text-sm rounded-md max-w-lg mx-auto", data: {"#{controller_name}-target" => "flash"}) if notice),
        (tag.div(alert, class: "mb-2 p-3 bg-red-50 text-danger text-sm rounded-md max-w-lg mx-auto", data: {"#{controller_name}-target" => "flash"}) if alert)
      ].compact_blank)
    end
  end

  private

  def data_attributes
    {data: {
      controller: controller_name
    }}
  end

  def controller_name
    "flash-component--flash-component"
  end
end
