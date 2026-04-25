# frozen_string_literal: true

# Shared page header: [back arrow][title centered][optional action].
# Either side slot may be omitted; the title stays centered because empty
# slots render an invisible spacer the same size as a button.
#
# Usage:
#   = render PageHeaderComponent.new(title: "Settings", back_href: today_path)
#   = render PageHeaderComponent.new(title: "Recipes", back_href: today_path) do |h|
#     - h.with_action do
#       = link_to new_recipe_path, "aria-label": "New recipe", class: "..." do
#         <svg>...</svg>
#
# `back_href` takes a URL; the back-arrow icon and aria-label are built in.
# The action slot is free-form so callers can supply any button or link.
class PageHeaderComponent < ViewComponent::Base
  renders_one :action

  BACK_ARROW_SVG = '<svg class="w-5 h-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5"/></svg>'.html_safe.freeze

  def initialize(title:, back_href: nil, back_label: "Back")
    @title = title
    @back_href = back_href
    @back_label = back_label
  end
end
