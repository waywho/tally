# frozen_string_literal: true

class FlashComponentPreview < ViewComponent::Preview
  def default
    render(FlashComponent.new(notice: "I have notice!", alert: "Oh no"))
  end
end
