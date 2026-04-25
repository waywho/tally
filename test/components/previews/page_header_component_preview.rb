# frozen_string_literal: true

class PageHeaderComponentPreview < ViewComponent::Preview
  def default
    render(PageHeaderComponent.new(title: "title"))
  end
end
